require "mini_magick"

# Generates the 1200x630 images used for Open Graph / Twitter cards.
#
# Post covers are full-size originals (several MB, arbitrary aspect ratio).
# Facebook, LinkedIn and X all want a card that is close to 1.91:1 and well
# under 5 MB, and they will skip or badly crop anything else. So, in the same
# spirit as thumbnail_generator.rb, we derive a dedicated card from the cover.
#
# Unlike thumbnails and gallery items, the output path is *not* declared in
# front matter - it is derived from the cover path, so no post has to be
# touched. The result is exposed to Liquid as `page.social_image` and picked up
# by _includes/head.html.
#
# The site-wide fallback (used on the index, category, tag and archive pages) is
# generated the same way from `site.cover` and lands in
# `site.social_image.default`.
#
# Configure in _config.yml:
#
#   social_image:
#     dir: "/assets/social"
#     width: 1200
#     height: 630
#     quality: 82
#
module Jekyll
  class SocialImageGenerator < Generator
    safe true
    # After the thumbnail/gallery generators; nothing depends on the order, but
    # keeping image work together makes the build log readable.
    priority :low

    DEFAULTS = {
      "dir"     => "/assets/social",
      "width"   => 1200,
      "height"  => 630,
      "quality" => 82,
    }.freeze

    def generate(site)
      @site    = site
      @config  = DEFAULTS.merge(site.config["social_image"] || {})
      @source  = site.source
      @emitted = {}

      site.posts.docs.each do |post|
        next unless post.data["cover"]

        card = card_for(post.data["cover"])
        post.data["social_image"] = card if card
      end

      if site.config["cover"]
        default_card = card_for(site.config["cover"], "site-default")
        if default_card
          site.config["social_image"] = @config.merge("default" => default_card)
        end
      end
    end

    private

    # Site-relative path of the card for `cover`, or nil when the source image
    # is missing. Generates the file if it is absent or out of date, and
    # registers it as a static file so a fresh checkout gets it copied to the
    # destination on the same build that creates it.
    def card_for(cover, name = nil)
      name ||= card_name(cover)
      rel    = File.join(@config["dir"], "#{name}.jpg")
      return @emitted[rel] if @emitted.key?(rel)

      input  = File.join(@source, cover)
      output = File.join(@source, rel)

      unless File.exist?(input)
        Jekyll.logger.warn "SocialImage:", "cover not found, skipping: #{cover}"
        return @emitted[rel] = nil
      end

      render(input, output) if stale?(input, output)
      register(rel)

      @emitted[rel] = rel
    end

    def stale?(input, output)
      !File.exist?(output) || File.mtime(output) <= File.mtime(input)
    end

    def render(input, output)
      Jekyll.logger.info "SocialImage:", "generating #{output}"
      FileUtils.mkdir_p(File.dirname(output))

      geometry = "#{@config['width']}x#{@config['height']}"
      image = MiniMagick::Image.open(input)
      image.combine_options do |img|
        img.strip
        img.auto_orient
        # `^` fills the box (the smaller side matches), then a centred crop
        # takes the 1.91:1 middle of the photo.
        img.resize "#{geometry}^"
        img.gravity "center"
        img.extent "#{geometry}+0+0"
        img.quality @config["quality"].to_s
        img.interlace "Plane"
      end
      image.format "jpg"
      image.write output
    end

    # Jekyll builds its static-file list before generators run, so a card
    # created during this build is invisible to it unless we add it ourselves.
    def register(rel)
      return if @site.static_files.any? { |f| f.relative_path == rel }

      dir  = File.dirname(rel)
      base = File.basename(rel)
      @site.static_files << Jekyll::StaticFile.new(@site, @source, dir, base)
    end

    # "/assets/Italy/Pisa/20251019_143343_01.jpg" -> "Italy-Pisa-20251019_143343_01"
    #
    # Flattening the whole path rather than using the basename keeps two covers
    # with the same filename in different country folders from colliding.
    def card_name(cover)
      cover.sub(%r{\A/?assets/}, "")
           .sub(/\.[^.\/]+\z/, "")
           .gsub(%r{[/\s]+}, "-")
           .gsub(/[^A-Za-z0-9._-]/, "")
    end
  end
end

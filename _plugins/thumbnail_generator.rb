module Jekyll
  module ThumbnailFilter
    def thumbnail_filter(input)
      basename = File.basename(input, File.extname(input))
      resized = basename + '.thumbnail.jpg'
      resized_path = "./assets/thumbnails/#{resized}"
      resized_url = "/assets/thumbnails/#{resized}"
      if !File.exists?(resized_path) || File.mtime(resized_path) <= File.mtime(input)
        dimensions = Jekyll.configuration({})['post_image']['dimensions']
        image = MiniMagick::Image.open(input)
        image.strip
        image.resize dimensions
        image.write resized_path
      end
      """#{resized_url}"""
    end
  end
end

Liquid::Template.register_filter(Jekyll::ThumbnailFilter)

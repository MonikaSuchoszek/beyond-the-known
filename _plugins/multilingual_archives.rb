module Jekyll
  class MultilingualYearArchive < Page
    def initialize(site, base, dir, year, lang, posts, locale = nil)
      @site = site
      @base = base
      @dir = File.join(lang, 'archives', year)
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'year-archive.html')

      # Set basic page data
      self.data['year'] = year
      self.data['lang'] = lang
      self.data['title'] = "#{year} Archives"
      self.data['post_id'] = "archives_#{year}"

      # Set locale - prioritize passed locale, then from posts, then fallback
      if locale
        self.data['locale'] = locale
      elsif posts && posts.length > 0 && posts.first.data['locale']
        self.data['locale'] = posts.first.data['locale']
      else
        # This shouldn't happen if config is set up correctly, but provide fallback
        self.data['locale'] = "#{lang}_#{lang.upcase}"
      end

      # Store posts for the template
      self.data['posts'] = posts
    end
  end

  class MultilingualYearArchiveGenerator < Generator
    safe true
    priority :low

    def generate(site)
      return unless site.layouts.key? 'year-archive'

      # Group posts by language and year
      posts_by_lang_year = {}
      locale_by_lang = {}

      site.posts.docs.each do |post|
        # Extract language from post path or post data
        lang = extract_language_from_post(post)
        next unless lang

        # Store the locale for this language (from the post's config-applied data)
        if post.data['locale']
          locale_by_lang[lang] = post.data['locale']
        end

        year = post.date.year.to_s
        posts_by_lang_year[lang] ||= {}
        posts_by_lang_year[lang][year] ||= []
        posts_by_lang_year[lang][year] << post
      end

      # Generate archive pages
      posts_by_lang_year.each do |lang, years|
        # Get the locale for this language from config defaults
        locale = locale_by_lang[lang] || get_locale_from_config(site, lang)

        years.each do |year, posts|
          # Sort posts by date (newest first)
          sorted_posts = posts.sort { |a, b| b.date <=> a.date }

          # Create archive page with locale from config
          archive_page = MultilingualYearArchive.new(site, site.source, '', year, lang, sorted_posts, locale)
          site.pages << archive_page
        end
      end
    end

    private

    def extract_language_from_post(post)
      # First try to get language from post's locale data
      if post.data['locale']
        # Extract language from locale (e.g., 'en_US' -> 'en')
        return post.data['locale'].split('_').first
      end

      # Fallback: extract from post path
      match = post.path.match(/_posts\/([a-z]{2})\//)
      match ? match[1] : nil
    end

    def get_locale_from_config(site, lang)
      # Look through site defaults to find locale for this language path
      if site.config['defaults']
        site.config['defaults'].each do |default|
          scope = default['scope']
          values = default['values']

          # Check if this default applies to posts in our language directory
          if scope && scope['path'] && scope['type'] == 'posts' &&
             scope['path'].include?("_posts/#{lang}") && values && values['locale']
            return values['locale']
          end
        end
      end

      # Fallback if not found in config
      "#{lang}_#{lang.upcase}"
    end
  end
end
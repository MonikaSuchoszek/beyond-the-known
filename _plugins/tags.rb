module Jekyll
  class TagPageGenerator < Generator
    safe true

    def generate(site)
      languages = Jekyll.configuration({})['languages']
      languages.each do |language|
        posts = site.posts.docs.select { |post| post['locale'] == language['locale'] }
        tags = posts.flat_map { |post| post.data['tags'] || [] }.to_set
        tags.each do |tag|
          site.pages << TagPage.new(site, site.source, tag, language['locale'])
        end
      end
    end
  end

  class TagPage < Page
    def initialize(site, base, tag, locale)
      @site = site
      @base = base
      @dir  = File.join('tag', locale, tag)
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'tag.html')
      self.data['tag'] = tag
      self.data['locale'] = locale
      self.data['title'] = "Tag: #{tag}"
      # Tag pages are thin by nature and most have one or two posts. Keep them
      # for readers and internal link flow, but keep them out of the index and
      # out of the sitemap (honoured by jekyll-sitemap).
      self.data['noindex'] = true
      self.data['sitemap'] = false
      # Not indexed, but the description still shows up when someone shares the
      # URL, and it costs nothing to make it say which tag this is.
      self.data['description'] = tag_description(site, locale, tag)
    end

    private

    def tag_description(site, locale, tag)
      strings = (site.data['translations'] || {})[locale] || {}
      template = strings['tag_description']
      return nil unless template

      template.gsub('%{tag}', tag)
    end
  end
end

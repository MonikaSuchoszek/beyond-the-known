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
    end
  end
end

module Jekyll
  class CategoryPageGenerator < Generator
    safe true

    def generate(site)
      languages = Jekyll.configuration({})['languages']
      languages.each do |language|
        posts = site.posts.docs.select { |post| post['locale'] == language['locale'] }
        categories = posts.flat_map { |post| post.data['categories'] || [] }.to_set
        categories.each do |category|
          site.pages << CategoryPage.new(site, site.source, category, language['locale'])
        end
      end
    end
  end

  class CategoryPage < Page
    def initialize(site, base, category, locale)
      @site = site
      @base = base
      @dir  = File.join('category', locale, category)
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'category.html')
      self.data['category'] = category
      self.data['locale'] = locale
      self.data['title'] = "Category: #{category}"
    end
  end
end

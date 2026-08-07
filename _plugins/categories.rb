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
      entry = entry_for(site, category, locale)

      self.data['category'] = category
      self.data['locale'] = locale
      self.data['title'] = "Category: #{label_for(entry, category)}"
      # Intro copy rendered on the page and reused as the meta description, so
      # category pages stop sharing one duplicate site-wide description.
      self.data['intro'] = entry && entry['desc'].to_s.strip
      self.data['description'] = self.data['intro']
    end

    def entry_for(site, category, locale)
      (site.config['descriptions'] || []).find do |desc|
        desc['cat'].to_s.strip == category && desc['locale'] == locale
      end
    end

    # Reader-facing name of the category; see _plugins/category_label.rb
    def label_for(entry, category)
      display = entry && entry['display']
      display.to_s.empty? ? category.sub(/\S/) { |char| char.upcase } : display
    end
  end
end

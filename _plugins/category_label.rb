# Liquid filter: {{ cat | category_label: post.locale }}
#
# Category slugs are kept ASCII-only so that URLs, Pagefind globs and the
# `descriptions` list in _config.yml all line up (e.g. `podroze`). The label
# shown to readers can differ: add a `display:` key next to `cat:` in
# _config.yml to override it (e.g. `podroze` -> `Podróże`).
#
# Falls back to the slug with its first character upcased, i.e. the same result
# the previous `| capitalize` gave.
module Jekyll
  module CategoryLabelFilter
    def category_label(category, locale = nil)
      slug = category.to_s
      return slug if slug.empty?

      site = @context.registers[:site]
      entry = (site.config['descriptions'] || []).find do |desc|
        desc['cat'].to_s.strip == slug && (locale.nil? || desc['locale'] == locale)
      end

      label = entry && entry['display']
      label = slug.sub(/\S/) { |char| char.upcase } if label.nil? || label.to_s.empty?
      label
    end
  end
end

Liquid::Template.register_filter(Jekyll::CategoryLabelFilter)

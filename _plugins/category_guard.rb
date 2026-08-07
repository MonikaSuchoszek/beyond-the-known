# Build-time guard: every post category must have a matching entry in
# `descriptions` in _config.yml for that post's locale.
#
# Without this, a mistyped category (e.g. `podróże` instead of `podroze`) fails
# silently: the post gets its own URL tree, never shows up on the /<lang>/posts/
# listing page (which iterates site.descriptions) and is missed by the Pagefind
# globs. Fail loudly instead.
module Jekyll
  Hooks.register :site, :post_read do |site|
    descriptions = site.config['descriptions'] || []

    # locale => Set of allowed category slugs
    allowed = Hash.new { |hash, key| hash[key] = [] }
    descriptions.each do |entry|
      allowed[entry['locale']] << entry['cat'].to_s.strip
    end

    problems = []

    site.posts.docs.each do |post|
      path = post.relative_path
      locale = post.data['locale']

      if locale.nil? || locale.to_s.empty?
        problems << "#{path}: no `locale` set (check the `defaults` in _config.yml)."
        next
      end

      categories = post.data['categories'] || []
      if categories.empty?
        problems << "#{path}: no `categories` set."
        next
      end

      categories.each do |category|
        next if allowed[locale].include?(category.to_s)

        known = allowed[locale].sort.join(', ')
        known = '(none defined for this locale)' if known.empty?
        problems << "#{path}: category `#{category}` is not defined for locale " \
                    "`#{locale}`. Known categories: #{known}."
      end
    end

    unless problems.empty?
      Jekyll.logger.error 'Category check:', "#{problems.size} problem(s) found."
      problems.each { |problem| Jekyll.logger.error '', "- #{problem}" }
      Jekyll.logger.error '', 'Fix the category in the post front matter, or add it to'
      Jekyll.logger.error '', '`descriptions` in _config.yml (and to the globs in pagefind.yaml).'
      Jekyll.logger.abort_with 'Build aborted:', 'unknown post categories.'
    end
  end
end

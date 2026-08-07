# Warns about future-dated posts at build time.
#
# `future: true` in _config.yml is deliberate: drafts dated ahead should show up
# while previewing the site locally. The risk is publishing one by accident - a
# future-dated post emits a future `lastmod` in the sitemap and a future
# `datePublished` in the BlogPosting schema, both of which search engines handle
# poorly.
#
# So rather than turning `future` off, the build says out loud which posts are
# dated ahead, and how far, every time it runs.
module Jekyll
  class FuturePostsWarning < Generator
    safe true
    priority :lowest

    def generate(site)
      return unless site.config['future']

      now = site.time
      future_posts = site.posts.docs.select { |post| post.date > now }
      return if future_posts.empty?

      Jekyll.logger.warn "Future posts:",
                         "#{future_posts.size} post(s) dated after #{now.strftime('%Y-%m-%d')} " \
                         "are being published because `future: true` is set in _config.yml."

      future_posts.sort_by(&:date).each do |post|
        days = ((post.date - now) / 86_400.0).ceil
        Jekyll.logger.warn "", "  #{post.date.strftime('%Y-%m-%d')} (in #{days} day#{'s' unless days == 1}) " \
                               "#{post.relative_path}"
      end

      Jekyll.logger.warn "", "  Set `future: false` before deploying if these are not meant to be live."
    end
  end
end

# Precomputes, once per build, the data that header.html, footer.html,
# alternates.html and post.html used to derive by looping over site.pages and
# site.posts on every single page render.
#
# In Jekyll 3 every property read on a Page from Liquid (`link.title`,
# `link.locale`, ...) rebuilds the page's whole data hash, so those loops cost
# ~95 s per build. Doing the work here once takes milliseconds. See speedup.md.
#
# Sets:
#   site.data['nav'][locale]  -> [{ 'title' => ..., 'url' => ... }, ...]
#                                pages with `main_nav: true`, in site.pages order
#   page.alternates           -> ["<locale>~<canonical url>", ...]
#                                this page's translations (format documented in
#                                _includes/alternates.html)
#   post.prev_post            -> { 'title' => ..., 'url' => ... } or unset
#   post.next_post               the next older / newer post in the same locale
module Jekyll
  module PrecomputeNavigation
    module_function

    def run(site)
      build_nav(site)
      build_alternates(site)
      build_prev_next(site)
    end

    # Same rule as _includes/canonical_url.html: drop a trailing "index.html",
    # but only when there is something in front of it.
    def canonical(url)
      url.size > 10 && url.end_with?('index.html') ? url[0...-10] : url
    end

    def build_nav(site)
      nav = Hash.new { |hash, key| hash[key] = [] }
      site.pages.each do |page|
        next unless page.data['title'] && page.data['main_nav'] == true

        nav[page.data['locale']] << { 'title' => page.data['title'], 'url' => page.url }
      end
      site.data['nav'] = nav
    end

    # Translations are matched on post_id. Posts are looked at first, then
    # pages, and the last match wins - the same precedence the two Liquid loops
    # had. Items without a post_id fall back to each locale's index.
    def build_alternates(site)
      languages = site.config['languages'] || []
      items = site.posts.docs + site.pages

      by_id = Hash.new { |hash, key| hash[key] = {} }
      items.each do |item|
        id = item.data['post_id']
        by_id[id][item.data['locale']] = item.url if id
      end

      items.each do |item|
        id = item.data['post_id']
        item.data['alternates'] = languages.each_with_object([]) do |language, list|
          url = id ? by_id[id][language['locale']] : language['index']
          list << "#{language['locale']}~#{canonical(url)}" if url && !url.empty?
        end
      end
    end

    # site.posts.docs is sorted oldest first, so within a locale the previous
    # (older) post is the one before and the next (newer) the one after.
    def build_prev_next(site)
      site.posts.docs.group_by { |post| post.data['locale'] }.each_value do |posts|
        posts.each_with_index do |post, index|
          older = index.positive? ? posts[index - 1] : nil
          newer = posts[index + 1]
          post.data['prev_post'] = link_to(older)
          post.data['next_post'] = link_to(newer)
        end
      end
    end

    def link_to(post)
      post && { 'title' => post.data['title'], 'url' => post.url }
    end
  end

  Hooks.register :site, :pre_render do |site|
    PrecomputeNavigation.run(site)
  end
end

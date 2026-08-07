# SEO Audit & Improvement Plan — beyond-the-known.eu

**Date:** 2026-08-06
**Scope:** Template, config and asset-level review of the Jekyll site. No structural rewrite, no move away from a static site.
**Method:** Read of `_layouts/`, `_includes/`, `_plugins/`, `_config.yml`, `_data/`, sample posts, plus inspection of the generated output in `docs/` and two live-URL checks.

---

## Executive summary

The site is technically sound in the basics — clean semantic HTML, one `<h1>` per page, canonical tags, a sitemap, a valid `robots.txt`, mobile viewport, HTTPS, and reasonable permalink structure. The content itself is genuinely good: long-form, first-hand, keyword-aware travel writing in three languages.

What is holding it back is almost entirely fixable at template level. The five things that matter most, in order:

1. **No `hreflang` annotations at all.** The site is trilingual with a working `post_id` translation link, but Google is given no signal that `/en/travel/2026/02/Massa/` and `/pl/podroze/2026/02/MassaPL/` are the same article. The three language versions compete with each other instead of reinforcing each other.
2. **Image weight.** 1,945 images, 825 MB total, 434 KB average, 661 files over 500 KB, one cover at 4.0 MB. Zero WebP/AVIF, no `loading="lazy"`, no `width`/`height`, no `srcset`. This is a direct Core Web Vitals hit (LCP + CLS) on exactly the mobile traffic a travel blog lives on.
3. **No structured data.** No JSON-LD anywhere. No `Article`/`BlogPosting`, no `BreadcrumbList`, no `ImageObject`. This is the cheapest available rich-result win and it is entirely missing.
4. **Homepages missing from the sitemap.** `/`, `/pl/` and `/nl/` do not appear in `sitemap.xml`. The Polish homepage also lives behind a literal directory named `index.html`, so its pagination is at `/pl/index.html/page/2/`.
5. **Post bodies have no subheadings.** Only 7 of 68 English posts use any markdown heading. Section titles are written as `**bold text**` instead of `###`, which forfeits topical structure, featured-snippet eligibility and jump-links.

Everything below is grouped by priority with a concrete, template-only fix for each.

---

## P0 — High impact, low-to-medium effort

### 1. Missing `hreflang` — the single biggest structural SEO gap

**Finding.** `grep -rn hreflang _includes _layouts` returns exactly one hit: [header.html:76](_includes/header.html#L76), an `hreflang` attribute on a visible dropdown link. There is no `<link rel="alternate" hreflang="…">` in [head.html](_includes/head.html), and `jekyll-sitemap` does not emit `xhtml:link` alternates.

**Why it matters.** With 68 EN / 59 PL / 20 NL posts, many of which are direct translations sharing a `post_id`, Google currently treats each language version as an independent page. Consequences: split ranking signals between translations, wrong-language version served to a searcher, and near-duplicate detection between the EN and PL versions of image-heavy posts.

**Fix.** The matching logic already exists in [header.html:34-48](_includes/header.html#L34-L48) — it walks `site.posts` and `site.pages` looking for a matching `post_id`. Extract that block into a new `_includes/alternates.html` that returns the locale→URL list, then use it in both places:

```liquid
{%- comment -%} in head.html {%- endcomment -%}
{%- for entry in available_list -%}
  {%- assign parts = entry | split: '~' -%}
  {%- assign lang = parts[0] | split: '_' | first -%}
  <link rel="alternate" hreflang="{{ lang }}" href="{{ parts[1] | prepend: site.baseurl | prepend: site.url }}">
{%- endfor -%}
<link rel="alternate" hreflang="x-default" href="{{ site.url }}/">
```

Rules to respect, or the annotations are ignored:
- **Must be reciprocal.** If EN points to PL, PL must point back to EN. Emitting from the shared include guarantees this.
- **Must be self-referential.** Every page includes an `hreflang` pointing at itself.
- **Must be absolute URLs.**
- Language-only codes (`en`, `pl`, `nl`) are correct here — do not use `en_US`.

**Effort:** ~1 hour. **Impact:** High.

---

### 2. Image payload and Core Web Vitals

**Finding.**

| Metric | Value |
|---|---|
| Images in `assets/` | 1,945 |
| Total size | 825 MB |
| Average size | 434 KB |
| Files > 500 KB | 661 |
| Files > 1 MB | 16 |
| WebP / AVIF files | 0 |
| `loading="lazy"` occurrences in repo | 1 |
| `width`/`height` on content images | 0 |

Example: `assets/Italy/Pisa/20251019_170954_01.jpg` is 4.0 MB and is used as a gallery source. A single post like [Massa](_posts/en/2026-02-02-Massa.markdown) embeds ~15 full-resolution originals with no lazy-loading, all fetched eagerly on page load.

Also note the header images are heavier than they need to be for what they are: `assets/index_header.jpg` 345 KB, `assets/about_header.jpg` 441 KB, `assets/logo.png` 357 KB (a logo!). These are CSS `background-image` on the hero, so they are frequently the LCP element.

**Fix — three independent steps, in order of payoff:**

**(a) Add lazy-loading and intrinsic dimensions to content images.** The site already post-processes images in JS ([footer.html:143-170](_includes/footer.html#L143-L170) wraps every `article.post-content img` in a lightbox anchor). Do the equivalent at build time instead. Options that don't require touching 127 posts by hand:
- A small `_plugins/` Jekyll hook (`:documents, :post_render`) that rewrites `<img …>` in the rendered HTML, adding `loading="lazy"`, `decoding="async"`, and `width`/`height` read from the file with MiniMagick (already a dependency via [thumbnail_generator.rb](_plugins/thumbnail_generator.rb)). Cache dimensions in a JSON file so builds stay fast.
- The first image in a post should get `loading="eager"` + `fetchpriority="high"` rather than lazy, since it is often the LCP element.

`width`/`height` alone eliminates layout shift (CLS), which is a ranking signal and currently unmanaged — every post shifts as images stream in.

**(b) Generate and serve WebP.** Extend the existing [thumbnail_generator.rb](_plugins/thumbnail_generator.rb) pattern into a general derivative generator: for each `assets/**/*.jpg`, emit a `.webp` at ~1600px wide, quality 80. Typical saving on photographic content is 60-75%; 825 MB of JPEG becomes roughly 200-280 MB of WebP. Then emit `<picture>` in the same post-render hook:

```html
<picture>
  <source srcset="/assets/…/photo.webp" type="image/webp">
  <img src="/assets/…/photo.jpg" loading="lazy" width="…" height="…" alt="…">
</picture>
```

Keep the JPEG as fallback so nothing breaks and the lightbox still works.

**(c) Cap source resolution.** Nothing on the page renders wider than ~1000 CSS px. Re-encoding originals down to 1600px longest edge before commit would cut the repo dramatically and speed up every build. Consider this a content-workflow change (resize on export), not a template change.

**Effort:** (a) ~3 h, (b) ~4 h + one long rebuild, (c) ongoing workflow. **Impact:** High — this is the main lever on mobile ranking.

---

### 3. No structured data (JSON-LD) [FIXED]

**Finding.** Zero occurrences of `application/ld+json`, `schema.org` or `itemscope` in any layout or include. The only microdata is a stray `itemprop="description"` at [index.html:24](_includes/index.html#L24) with no enclosing `itemscope`, which does nothing.

**Fix.** Add `_includes/schema.html`, included from [head.html](_includes/head.html), emitting per page type:

- **Posts → `BlogPosting`**: `headline` (`page.title`), `image` (`page.cover`, absolute), `datePublished` (`page.date | date_to_xmlschema`), `dateModified`, `author` (`Person`, `site.name`), `publisher`, `inLanguage` (from `page.locale`), `keywords` (from `page.tags`), `articleSection` (from `page.categories`), `mainEntityOfPage`.
- **All pages → `BreadcrumbList`**: Home › Category › Post. This regularly earns the breadcrumb display in the SERP in place of the raw URL, which measurably lifts CTR.
- **Site root → `WebSite`** with `name`, `url`, `inLanguage`.
- Optional: `ImageObject` on gallery items, `Place`/`geo` on posts that already carry `coords` in front matter — the lat/lng is already there and unused outside the map.

All values are already present in front matter; this is pure template work.

**Effort:** ~2-3 h. **Impact:** High (rich results, entity understanding).

---

### 4. Homepages absent from `sitemap.xml`; awkward `/pl/index.html` permalink [FIXED]

**Finding.**
- `sitemap.xml` contains 330 URLs but **not** `https://www.beyond-the-known.eu/` — verified by grep, zero matches. `/pl/` and `/nl/` are likewise absent (only `/pl/about/`, `/pl/galeria/` etc. are present).
- [pl/index.html](pl/index.html) and [nl/index.html](nl/index.html) declare `permalink: /pl/index.html`. Jekyll interprets this as a path, producing a **directory literally named `index.html`** containing the page and its `page/` pagination. Confirmed on disk: `docs/pl/index.html/` is a directory holding `index.html` and `page/`.
- Net effect: Polish pagination lives at `/pl/index.html/page/2/`, and the Polish homepage is served from `/pl/index.html/index.html`. Both `/pl/` and `/pl/index.html` resolve live (checked — GitHub Pages serves the directory index), so this is not user-facing breakage, but it is two URLs for one page and an ugly pagination path.

**Fix.**
- Change the permalink to `permalink: /pl/` and `permalink: /nl/`, and update `site.languages[].index` in [_config.yml](_config.yml#L50-L67) from `/pl/index.html` to `/pl/`. The canonical filter at [head.html:72](_includes/head.html#L72) already strips `index.html`, so canonicals stay correct either way — this fixes the *internal links* and the pagination path.
- The English homepage is at the site root, so its `index` value `/index.html` should become `/`.
- Verify the homepages then appear in the sitemap after rebuild. If `jekyll-sitemap` still skips them, add `sitemap: true` to their front matter.
- **Migration care:** if `/pl/index.html/page/2/` URLs are already indexed, they will 404 after the change. Given they are not in the sitemap and are almost certainly not indexed, the risk is low — but check Search Console before/after.

**Effort:** ~30 min + verification. **Impact:** Medium-High.

---

### 5. Duplicate Polish category slug: `podroze` vs `podróże` [FIXED]

**Finding.** Three Polish posts use `categories: podróże` (with diacritics) instead of `podroze`:
- [_posts/pl/2020-08-09-Zeeland-Cadzand.markdown](_posts/pl/2020-08-09-Zeeland-Cadzand.markdown)
- [_posts/pl/2020-09-06-Belgium-Namur.markdown](_posts/pl/2020-09-06-Belgium-Namur.markdown)
- [_posts/pl/2025-12-05-Italy.markdown](_posts/pl/2025-12-05-Italy.markdown)

(Category counts in `_posts/pl`: 51 × `podroze`, 1 × `sport`, plus these outliers.)

Consequences, all confirmed in the build:
- Two parallel URL trees exist: `docs/pl/podroze/` and `docs/pl/podróże/`, with the latter percent-encoded in the sitemap as `/pl/podr%C3%B3%C5%BCe/2024/10/Gandia_Cullera-miasto/`.
- `site.descriptions` in [_config.yml](_config.yml#L132) only lists `podroze`, so these posts **never appear** on the `/pl/posts/` listing page ([posts.html](_includes/posts.html) requires a matching description entry).
- The Pagefind glob in [pagefind.yaml](pagefind.yaml#L3) only covers `pl/podroze/**`, so **these posts are not in site search**.
- A near-empty duplicate category page is generated for `podróże`.

**Fix.** Change `categories: podróże` → `categories: podroze` in those three posts, then add 301-equivalent handling. On a static GitHub Pages site the practical option is a small HTML redirect stub (or the `jekyll-redirect-from` plugin, which GitHub Pages supports natively) at the old percent-encoded paths pointing to the new ones. If Search Console shows no impressions on those URLs, a plain rename with no redirect is acceptable.

Also worth adding: a build-time guard in a plugin that fails the build if a post's category is not in the `site.descriptions` list for its locale — this class of bug is silent and has clearly happened more than once.

**Effort:** ~1 h. **Impact:** Medium-High (3 posts currently invisible to two navigation systems).

---

## P1 — Medium impact

### 6. `<title>` tags are bare and non-descriptive on generated pages

**Finding.** [head.html:6](_includes/head.html#L6) is `<title>{{ page.title }}</title>` with no site name. Generated pages inherit developer-facing titles that are **English-only regardless of locale**:

| Page | Current `<title>` |
|---|---|
| EN post | `A Stay in Massa and a Day Trip to Pisa` |
| Category (any locale) | `Category: travel` ← from [categories.rb:27](_plugins/categories.rb#L27) |
| Tag (any locale) | `Tag: baby` |
| Year archive (any locale) | `2017 Archives` ← from [multilingual_archives.rb:15](_plugins/multilingual_archives.rb#L15) |
| Homepage | `Going beyond the known` |

A Polish user sees `Category: podroze` in the SERP. Titles are the highest-leverage on-page ranking element.

**Fix.**
- Template: `<title>{% if page.title %}{{ page.title }} · {{ site.title }}{% else %}{{ site.title }} — {{ items_text.subtitle }}{% endif %}</title>`. Keep the total under ~60 chars where possible; consider a `seo_title` front-matter override for posts whose display title is long.
- Localise generated titles: move the strings into [_data/translations.yml](_data/translations.yml) (`category_line`, `tag_line`, `archives` already exist and are already localised — the plugins just aren't using them) and have the layouts build the title from `items_text` instead of the plugin hardcoding `page.title`. The layouts already render the correct localised `<h1>`; only the `<title>` lags.
- Paginated pages should read `… · Page 2` to avoid 10 identical `Going beyond the known` titles.

**Effort:** ~2 h. **Impact:** Medium-High.

---

### 7. Meta descriptions

**Finding.** [head.html:7](_includes/head.html#L7) falls back to `page.excerpt | truncate: 160`, which produces mid-sentence cutoffs — the Massa post's description ends `"I'm sharing our real..."`. Category, tag, archive, gallery and map pages have **no** `page.excerpt`, so all ~180 of them emit the identical `A travel blog by Monika Suchoszek.` Duplicate meta descriptions across 180 URLs is a classic Search Console warning.

**Fix.**
- Add an optional `description:` front-matter field and prefer it: `{% if page.description %}…{% elsif page.excerpt %}…{% endif %}`. Backfill it on the top ~20 posts by traffic first; the rest can keep the excerpt fallback.
- Give category pages a real description — [_config.yml](_config.yml#L119-L154) already has localised `descriptions` per category, and [category.html](_layouts/category.html) currently **doesn't render them at all**. Surface them both as the meta description and as visible intro copy on the page (see §11).
- Localise the site-level fallback via `items_text.credit`, which is already translated in all three languages.

**Effort:** ~2 h. **Impact:** Medium.

---

### 8. Open Graph / Twitter Card metadata is partly wrong [FIXED]

**Findings** in [head.html:40-60](_includes/head.html#L40-L60):

| Issue | Detail |
|---|---|
| `og:type` is `website` on every page | Should be `article` for posts. Currently hardcoded at [line 46](_includes/head.html#L46). |
| `og:image:type` hardcoded `image/png` | But post covers are JPEG. Verified on the built Massa page: `og:image` is a `.jpg`, `og:image:type` says `image/png`. |
| `og:image:width/height` hardcoded `612 × 605` | These are the *logo's* dimensions, applied even when `og:image` is a 4 MB landscape cover. Facebook/LinkedIn will render the card wrong or skip it. |
| `og:image` is the full-size original | The Massa cover is served at full resolution to every scraper. OG images should be ~1200 × 630 and well under 5 MB. |
| Missing | `og:locale`, `og:locale:alternate`, `og:image:alt`, `article:published_time`, `article:modified_time`, `article:author`, `article:section`, `article:tag` |
| Missing | `twitter:site`, `twitter:creator`, `twitter:image:alt` |
| Dead code | [lines 62-68](_includes/head.html#L62-L68) reference `protocols.*` instead of `site.protocols.*`, so the Open Source Protocol block never renders. Harmless but should be deleted. |

**Fix.** Either drop the width/height/type triplet entirely (Facebook infers them) or — better — generate a dedicated 1200×630 social card per post in the same MiniMagick generator that makes thumbnails, and point `og:image` at that. Add the missing `article:*` and `og:locale` tags; all values are in front matter already. Social metadata isn't a direct ranking factor but it drives the shares and referral links that *are*.

**Effort:** ~2 h (+1 h if generating social cards). **Impact:** Medium.

---

### 9. Alt text coverage

**Finding.** In `_posts/en/`: 1,404 `<img>` tags, of which **338 have an `alt` attribute — 24%**. Only 24 of 68 posts use `alt` at all. Additionally:
- [index.html:26](_includes/index.html#L26) — homepage post thumbnails have no `alt`.
- [gallery.html:10](_includes/gallery.html#L10) — gallery images use `title=` but no `alt`.
- [post.html:5](_layouts/post.html#L5) and [year-archive.html:6](_layouts/year-archive.html#L6) — hidden Pagefind meta images, `alt` not needed but `alt=""` would be correct.

**Why it matters.** Alt text is the primary ranking signal for Google Images, which is a meaningful traffic source for a photo-heavy travel blog. It is also an accessibility requirement, and accessibility signals increasingly correlate with quality assessment.

**Fix.**
- Template-level (immediate): `alt="{{ post.title }}"` on homepage thumbnails, `alt="{{ item.description | strip_html | truncate: 120 }}"` on gallery items — the gallery already has good descriptive text sitting in `title=`, it just needs to be in `alt` too.
- Content-level (incremental): the 1,066 missing alts are a content job, not a template job. Prioritise: (1) the first image of each post — often the LCP element, (2) posts that already rank, (3) everything else over time. A build-time warning listing images without `alt` would make this tractable.

**Effort:** template 30 min; content backlog ongoing. **Impact:** Medium (high for image search specifically).

---

### 10. Post bodies have no heading structure

**Finding.** Only **7 of 68** English posts contain any markdown heading (`##`/`###`). The generated Massa page has exactly one `<h1>` (the title), one `<h2>` (the search modal), one `<h3>` (the footer) — and **nothing in the article body**. Section breaks are written as bold runs:

```markdown
**Chiesa di Santa Maria della Spina** is a tiny, ornate Gothic church…
**Ponte Solferino** located next to it had adorable views…
```

**Why it matters.** These are real section headings doing heading work with no heading markup. Consequences: no topical outline for Google, no eligibility for "jump to section" SERP links, weaker featured-snippet candidacy, and a wall of text that hurts dwell time on mobile. For a post targeting "Massa Pisa day trip with toddler", a `### Piazza dei Miracoli with a toddler` heading is a direct query-match surface.

**Fix.** This is a content-writing convention change, not a template change:
- Convert bold pseudo-headings to `###` (H3) under a few `##` (H2) section groupings.
- One H2 per major section (e.g. *Getting to Massa*, *What to do in Marina di Massa*, *Day trip to Pisa*, *Practical tips*).
- Where a post answers a question, phrase the heading as the question.
- Consider adding a small auto-generated table of contents include for posts over ~1,200 words — H2/H3s make this trivial, and it creates internal anchor links.

Style already exists in [_sass/](_sass/) for headings, so no CSS work needed. Document the convention in `README.md` so future posts follow it.

**Effort:** ~15 min per post retrofit; apply to the top 15-20 posts first. **Impact:** Medium-High on those posts.

---

### 11. Category pages are thin; tag pages are thin *and* numerous [FIXED]

**Findings.**
- [category.html](_layouts/category.html) renders an `<h1>` and a bare `<ul>` of post links. The localised category descriptions in [_config.yml](_config.yml#L119-L154) are **never rendered on the category page** — they only appear on the `/posts/` listing via [posts.html](_includes/posts.html). So a category page is a title and a link list: textbook thin content.
- **157 tag pages** exist in the build and appear in the sitemap. Many are single-post tags (e.g. `/tag/en_US/baby/` links to exactly one post). 161 of the 330 sitemap URLs — **49% of the sitemap** — are tag pages.
- Tag/category URLs embed the raw locale code: `/tag/en_US/running/`, `/category/en_US/travel/`. Machine-readable, not human- or search-friendly.
- The sitemap therefore spends half its crawl-budget signal on the site's weakest pages, while omitting the homepages entirely (§4).

**Fix.**
- **Category pages:** render `desc.desc` as visible intro copy (the data is already there and already translated), add post excerpts + thumbnails to the list instead of bare links, and set a proper meta description. This turns 9 thin pages into 9 legitimate landing pages for head terms like "travel blog Poland" / "podróże blog".
- **Tag pages:** add `<meta name="robots" content="noindex, follow">` to [tag.html](_layouts/tag.html) and exclude them from the sitemap (`sitemap: false` in the page data from [tags.rb](_plugins/tags.rb)). Keep them for user navigation and internal link flow — `follow` preserves the link equity — but stop asking Google to index 157 near-empty pages. This is the standard treatment and it is safe.
- Optionally consolidate: tags used by fewer than 3 posts add navigation noise; either merge them or don't generate pages for them.
- URL cleanup (`/tag/en/running/` or dropping the locale segment for English) is nice-to-have but requires redirects — low priority, and arguably not worth it.

**Effort:** ~2 h. **Impact:** Medium.

---

### 12. Weak internal linking

**Findings.**
- No **related posts** block anywhere. A post ends with tags, RSS, share buttons and prev/next — and prev/next is strictly chronological ([post.html:78-121](_layouts/post.html#L78-L121)), so a Georgia hiking post links to an unrelated Belgium post.
- No **breadcrumbs**, so no breadcrumb schema and no upward navigation from a post to its category.
- The homepage shows 7 posts; everything older is reachable only via pagination, the archives sidebar, or tag pages. With 147 posts, crawl depth to the oldest content is high.
- Cross-links between posts exist and are good where present (`{% post_url %}` used in the Massa post), but they are ad-hoc and manual.

**Why it matters.** Internal linking is how PageRank flows and how Google infers topical clusters. A travel blog with 147 posts across ~20 destinations should have strong destination clusters; right now it has a flat chronological chain.

**Fix — all template-only:**
- **Related posts include:** score other posts in the same locale by shared tags (weight 2) + shared category (weight 1), take the top 3-4, render with thumbnails below the article. Liquid can do this without a plugin; if build time suffers, precompute in a plugin.
- **Breadcrumbs** in [post.html](_layouts/post.html): `Home › {Category} › {Title}`, paired with the `BreadcrumbList` JSON-LD from §3.
- **Make prev/next topical:** prefer the previous/next post sharing the same primary category, falling back to chronological.
- **Destination hub pages** (optional, higher effort): a page per country/region linking all posts about it. This is the highest-value internal-linking move for a travel blog, and it fits the static model fine — it can be generated from tags by a plugin.

Note also: the current prev/next implementation loops over *all* `site.posts` twice per post — O(n²) over 147 posts × 3 locales. Worth replacing with a precomputed neighbour map while touching this code.

**Effort:** ~4 h. **Impact:** Medium-High.

---

## P2 — Performance and hygiene

### 13. Third-party render-blocking resources [FIXED]

**Finding.** Every page loads from **six different external hosts**:

| Resource | Host | Note |
|---|---|---|
| Font Awesome 4.6.3 CSS | maxcdn.bootstrapcdn.com | render-blocking; 2016 version |
| highlight.js CSS 9.9.0 | cdnjs.cloudflare.com | render-blocking |
| lightbox2 2.7.1 CSS | cdnjs.cloudflare.com | render-blocking |
| AOS CSS | unpkg.com | render-blocking; `@next` unpinned |
| jQuery **3.4.1 uncompressed** | code.jquery.com | `jquery-3.4.1.js`, not `.min.js` — ~280 KB instead of ~88 KB |
| highlight.js **8.5** JS | cdnjs.cloudflare.com | version mismatch with its own 9.9.0 CSS |
| micromodal | unpkg.com | `@next`-style unpinned |
| AOS JS | unpkg.com | unpinned |

Four render-blocking stylesheets from three hosts, each costing a DNS lookup + TLS handshake before first paint. On a 4G mobile connection this alone is several hundred milliseconds of blocked rendering, before any of the 400 KB-average images load.

**Specific problems beyond the count:**
- **highlight.js is loaded on a travel blog with no code samples.** Both the CSS and JS can be deleted outright. `hljs.initHighlightingOnLoad()` at [footer.html:74](_includes/footer.html#L74) is also long-deprecated.
- **jQuery is loaded unminified.** One-character fix (`.min.js`) for ~190 KB.
- **`@next` and floating versions** mean the site's behaviour can change without a commit — a reliability risk, not just SEO.
- **AOS fade-in on post list items** ([index.html:20](_includes/index.html#L20)) starts homepage content at `opacity: 0` until JS executes. Googlebot renders JS so it will be seen, but it delays LCP and makes the largest paint dependent on a third-party script from unpkg.

**Fix, in order of effort/payoff:**
1. Delete highlight.js (CSS + JS). Zero risk, two lines.
2. Switch jQuery to `.min.js` and pin every version explicitly. Ten minutes.
3. Self-host the remaining libraries under `/js` and `/css`, and subset Font Awesome — the site uses roughly a dozen icons out of ~600. A subset saves ~70 KB and removes a whole host. Even better: replace the dozen icons with inline SVG and drop Font Awesome entirely.
4. Add `defer` to the non-critical scripts and inline the critical CSS for the hero/header.
5. Consider dropping AOS. It is ~15 KB plus a render dependency, purchasing a fade effect that costs LCP.

**Effort:** steps 1-2 ~30 min; steps 3-5 ~4 h. **Impact:** Medium-High (Core Web Vitals).

---

### 14. `robots.txt` exists only in the build output, not in source [FIXED]

**Finding.** `docs/robots.txt` exists (a single `Sitemap:` line) but there is **no `robots.txt` in the repository source**. Jekyll cleans its destination directory on build, so this file is one clean rebuild away from disappearing — at which point the sitemap reference is lost.

**Fix.** Create a source `robots.txt` at the repo root. Suggested content:

```
User-agent: *
Allow: /

Sitemap: https://www.beyond-the-known.eu/sitemap.xml
```

Verify it survives a rebuild. **Effort:** 5 min. **Impact:** Low-Medium (but it's a latent regression).

---

### 15. No 404 page

**Finding.** No `404.html` in source or output. GitHub Pages serves its generic 404.

**Fix.** Add a `404.html` with `permalink: /404.html` at the root, using the `page` layout, with links back to the three homepages, the category pages and the search modal. **Effort:** 20 min. **Impact:** Low (retention/crawl, not ranking).

---

### 16. `<html>` has no `lang` attribute on locale-less pages

**Finding.** [default.html:2-7](_layouts/default.html#L2-L7) only emits `<html lang="…">` when `page.locale` is set. Any page without a locale — a future 404 page, or any page where the front matter is forgotten — renders bare `<html>`.

**Fix.** Default to `en`: `<html lang="{% if page.locale %}{{ page.locale | split: '_' | first }}{% else %}en{% endif %}">`. **Effort:** 5 min. **Impact:** Low.

---

### 17. Pagefind search coverage gaps

**Finding.** [pagefind.yaml](pagefind.yaml#L3) globs only the category subtrees:
`{en/travel,en/sports,en/food,pl/sport,pl/podroze,pl/jedzenie,nl/sport,nl/reizen,nl/eten}/**/*.html`

Missing: `pl/podróże/**` (the three posts from §5), and the standalone pages (`about`, `posts`, `gallery`, `map`) in all three languages. The comment in [_config.yml:118](_config.yml#L118) already warns that categories must be kept in sync with this file — a coupling that has silently broken once already.

**Fix.** Fix the `podróże` category (§5), which removes that gap at the source. Add the page paths to the glob, or invert the config to index `docs/**/*.html` and rely on `data-pagefind-ignore` (already used on [category.html](_layouts/category.html#L6) and [tag.html](_layouts/tag.html#L6)) to exclude listing pages. Inverting removes the sync burden permanently.

Not a direct Google ranking factor, but on-site search that fails to find content hurts engagement metrics that are. **Effort:** 30 min. **Impact:** Low-Medium.

---

### 18. RSS feed mixes all three languages [FIXED]

**Finding.** [feed.xml](feed.xml) emits the 10 most recent posts across all locales into one feed, with no `<language>` element, no per-language feed, and full `post.content` in `<description>` (which, given image-heavy posts, makes for a very large feed). Both [footer.html:46](_includes/footer.html#L46) and [post.html:49](_layouts/post.html#L49) point every language at the same `/feed.xml`. The "Subscribe via RSS" label is also hardcoded English on Polish and Dutch pages.

**Fix.** Generate `/feed.xml`, `/pl/feed.xml`, `/nl/feed.xml` filtered by locale, add `<language>`, link the right one per locale, use `post.excerpt` rather than full content, and localise the label via `_data/translations.yml`. **Effort:** 1 h. **Impact:** Low.

---

### 19. Small correctness items [FIXED]

- **[post.html:73](_layouts/post.html#L73)** — stray duplicate `</a>` closing tag in the Twitter share block. Invalid HTML.
- **[head.html:62-68](_includes/head.html#L62-L68)** — Open Source Protocol block references `protocols.*` instead of `site.protocols.*`; the condition is always false and the block is dead. Delete it.
- **[year-archive.html:12,21](_layouts/year-archive.html#L12-L21)** — the page renders the same string as both `<h1 class="title">` and a second `<h1>` inside `.year-archive`. **Two `<h1>` elements on every archive page.** The inner one should be removed or demoted.
- **[year-archive.html:27](_layouts/year-archive.html#L27)** — `<time>` has no `datetime` attribute, so it carries no machine-readable value.
- **[index.html:28](_includes/index.html#L28)** — homepage excerpts use `post.content | strip_html | truncatewords: 50`, i.e. the entire post body is loaded and stripped for each of 7 cards, on every one of 10 paginated pages. Use `post.excerpt` instead; faster build, same output.
- **No `dateModified` anywhere.** Posts show only the original date. Freshness is a ranking factor for travel content (prices, opening hours, transport). Consider a `last_modified_at` front-matter field, surfaced in both the template and the `BlogPosting` schema.
- **`future: true`** in [_config.yml:23](_config.yml#L23) publishes future-dated posts. No posts are currently future-dated relative to today, but a post dated ahead would emit a future `lastmod` in the sitemap and a future `datePublished` — both of which search engines handle poorly. Worth being deliberate about.

**Effort:** ~1 h total. **Impact:** Low individually.

---

### 20. No Search Console / Bing verification [NOT AN ISSUE, done with DNS settings]

**Finding.** The only analytics is GoatCounter ([footer.html:55](_includes/footer.html#L55)). There is no Google Search Console verification meta tag or Bing verification.

**Why it matters.** Everything above is a hypothesis until measured. Search Console is the only source of truth for impressions, positions, index coverage errors, Core Web Vitals field data, and — critically for this site — hreflang validation errors. Without it, the P0 work cannot be verified.

**Fix.** Verify the domain in Google Search Console (DNS TXT is cleanest and avoids a template change) and Bing Webmaster Tools. Submit `sitemap.xml`. Then baseline: total impressions/clicks per language, top queries, Core Web Vitals status, and index coverage.

**Effort:** 30 min. **Impact:** Enabling — do this first.

---

## Suggested execution order

The phases are ordered so that measurement comes first, cheap high-impact fixes come next, and the expensive image work runs in the background throughout.

### Phase 0 — Instrument (half a day)
1. Google Search Console + Bing verification, submit sitemap (§20).
2. Baseline PageSpeed Insights / Lighthouse on the homepage and one image-heavy post, mobile.
3. Record current impressions, average position, and indexed-page count per language.

### Phase 1 — High impact, low effort (1-2 days)
4. `hreflang` in `<head>` (§1) — the biggest single win.
5. Fix the `podróże` category and the Pagefind glob (§5, §17).
6. Fix `/pl/` and `/nl/` permalinks; get homepages into the sitemap (§4).
7. `noindex, follow` on tag pages; remove them from the sitemap (§11).
8. Source `robots.txt` (§14); 404 page (§15); `<html lang>` fallback (§16).
9. Delete highlight.js; minify and pin jQuery (§13 steps 1-2).
10. Fix the OG image type/dimensions lie and add `og:type: article` + `article:*` (§8).
11. Small correctness items (§19).

### Phase 2 — Content surfaces (3-5 days)
12. JSON-LD: `BlogPosting` + `BreadcrumbList` + `WebSite` (§3).
13. Title template + localised generated titles (§6).
14. Meta description overrides; render category descriptions on category pages (§7, §11).
15. Related-posts block + breadcrumbs + topical prev/next (§12).
16. Template-level alt text on thumbnails and gallery (§9).

### Phase 3 — Performance (3-5 days, partly background)
17. Build-time `loading="lazy"` + `width`/`height` injection (§2a) — biggest CLS/LCP win per hour spent.
18. WebP derivative generation + `<picture>` output (§2b).
19. Self-host and subset the remaining third-party assets; `defer` scripts (§13 steps 3-5).
20. Generate 1200×630 social cards (§8).

### Phase 4 — Ongoing content work
21. Retrofit H2/H3 structure into the top ~20 posts (§10); adopt the convention for new posts.
22. Backfill alt text, prioritising first-image-per-post (§9).
23. Resize source images to ~1600px on export (§2c).
24. Consider destination hub pages (§12).
25. Add `last_modified_at` when updating older posts (§19).

---

## What is already good — don't break it

Worth stating explicitly, because several of these are things sites commonly get wrong:

- Clean, keyword-relevant, human-written long-form content with genuine first-hand experience — the thing that is hardest to fix and is already right. The Massa post's opening paragraph is a textbook search-intent match.
- Semantic HTML: `<header>`, `<nav>`, `<main>`, `<article>`, `<aside>`, `<footer>`, with correct `role` attributes.
- Exactly one `<h1>` per page (except the year archives, §19).
- Canonical tags on every page, correctly self-referencing on paginated pages, with `index.html` properly stripped.
- Working `sitemap.xml` via `jekyll-sitemap`, with accurate `lastmod`.
- A real translation-linking mechanism (`post_id`) already in place — §1 just needs to expose it to search engines.
- Localised UI strings via [_data/translations.yml](_data/translations.yml), covering all three languages consistently.
- Accessible language switcher with `aria-expanded`, `aria-controls`, keyboard arrow navigation and Escape handling — better than most sites.
- Privacy-respecting analytics (GoatCounter) with no cookie banner and negligible weight.
- HTTPS with a custom apex domain, and a sensible permalink structure.

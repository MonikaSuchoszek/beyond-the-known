---
name: translate
description: Translate an English blog post (from _posts/en) into Polish and Dutch, place the results in _posts/pl and _posts/nl following this site's conventions, then verify each translation by back-translating it to English and comparing meaning against the original — iterating until no meaningful differences remain. Use when the user runs /translate <post> or asks to translate/localize a post into Polish/Dutch.
---

# /translate — localize an English post into Polish and Dutch

## Arguments
`<post>` — a filename, slug, or path identifying the source post under `_posts/en/`
(e.g. `2026-08-01-HikesBE`, `HikesBE.markdown`, or a full path). Resolve it against
`_posts/en/*.markdown`.

## Step 1 — Read the source
Read the full source file, front matter included. Note its `post_id` — that's the
stable identifier used to detect existing translations.

## Step 2 — Find or choose the target files
- Grep `_posts/pl/*.markdown` and `_posts/nl/*.markdown` for the same `post_id:`.
  If a translation already exists, inform the user and ask if it needs to be updated or skipped.
- If no translation exists yet, create new files with the same date prefix as the
  source and the same slug. Place them in `_posts/pl/` and `_posts/nl/`.

## Step 3 — Reuse existing category and tags vocabulary
Grep `categories:` and `tags:` across `_posts/en`, `_posts/pl`, `_posts/nl` to see how existing
category words have already been translated (e.g. `travel`→`podroze`(PL)/`reizen`(NL),
`food`→`jedzenie`(PL), `sports`→`sport`). Reuse the established mapping instead of
inventing new wording, so category- and tag-based URLs and archive pages stay consistent
across the site and posts covering the same topics are connected through the tag pages.

## Step 4 — Translate
Delegate the actual translation to the `translator` subagent (Opus, medium effort —
defined in `.claude/agents/translator.md`) rather than translating it yourself
inline; it's tuned for this. Run it synchronously (you need its output before
continuing) and give it the full source file plus the category mapping from Step 3
and the target filename to write to. For each language:

**Translate:**
- `title`, `description`
- every `gallery_items[].description`
- `alt="..."` text on `<img>` tags in the body
- the full markdown/HTML body text
- `categories` (via the mapping from Step 3)
- `tags` (use previously used tags where possible)

**Copy unchanged:**
- `layout`, `date`, `author`, `cover`, `thumbnail`, `post_id`, `coords`
- `gallery_items[].image` and every image `src` path
- all URLs that aren't `post_url` tags

**Rewrite `{% post_url lang/slug %}` links:** point `lang` at `pl`/`nl` and `slug` at
that target post's PL/NL filename *if a translation of the linked post exists in that
language*. If it doesn't exist yet, leave the link pointing at `en/slug` rather than
create a dead link, and mention this in your final report.

Preserve all markdown/HTML structure exactly (headings, `<div class="row">` blocks,
image tags, bold/italic, link syntax, blank-line spacing) — only human-readable text
changes. Write the result to the target file.

## Step 5 — Verify by independent back-translation
For each of PL and NL, spawn a **fresh** `translator` subagent instance (same
Opus/medium-effort agent, run synchronously) with **only**:
- the full text of the translated file you just wrote
- the full text of the original English post
- instructions to translate the PL/NL file back into English itself, then compare
  that back-translation against the supplied original, and report only
  **meaning-level** issues (wrong facts, dropped or added sentences/paragraphs,
  mistranslated numbers/names/places/directions, tone or sentiment flips) — not
  stylistic wording differences. It should return a concrete list of issues with
  the offending sentence/field, or state there are none.

Giving the subagent a clean context (rather than checking it yourself) avoids you
grading your own translation from memory of the choices you just made.

## Step 6 — Fix and repeat
If the subagent flags meaning-level issues, correct just those spots in the
translated file (re-translate the affected field/sentence, keep everything else),
then re-run Step 5 for that language. Repeat until a verification pass comes back
clean. Cap at 3 rounds per language — if issues persist past that, stop and report
the residual concerns to the user instead of looping indefinitely.

## Step 7 — Report
Summarize for the user: which files were created/updated, the category mapping
used, any `post_url` links left pointing at English due to a missing translation,
and the verification outcome per language (clean on round N, or issues found and
fixed, or unresolved issues left for the user).

## Notes
- Never modify the English source file.
- Keep front-matter key order and formatting consistent with sibling files in the
  target language folder.
- If the post has images that don't exist yet for a language-specific reason, that's
  out of scope — assets are shared across languages via the same `/assets/...` paths.

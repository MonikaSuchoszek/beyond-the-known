---
name: review-post
description: Review a new or edited blog post before publishing — front-matter completeness, SEO description and title length, tag correctness and suggestions, missing image alt text, spelling and grammar, heading structure, coordinate sanity, clarity and internal linking. Small mechanical problems are fixed in place; anything needing a decision comes back as questions. Use when the user runs /review-post <post> or asks to check/proofread/QA a post.
---

# /review-post — pre-publish check on a post

## Arguments
`<post>` — a filename, slug, or path identifying a post (e.g. `2026-08-01-HikesBE`,
`HikesBE.markdown`, or a full path). Resolve it against `_posts/*/*.markdown`.
If no argument is given, use the post open in the editor, or the most recently
added/modified post per `git status`. Confirm which file you picked before editing.

English posts under `_posts/en/` are the normal target. A PL or NL file can be
reviewed too, but translation fidelity is not this skill's job — that's `/translate`.

## Step 1 — Gather context the reviewer needs
Before spawning anything, collect:
- The full target file.
- The site's tag vocabulary: grep `^tags:` across `_posts/en`, `_posts/pl`, `_posts/nl`
  and count how each tag is spelled, so casing disagreements are decidable.
- The category vocabulary: grep `^categories:` across the same.
- A list of other post titles/slugs with their `categories`/`tags`, for the
  internal-link suggestions.

## Step 2 — Run the reviewer
Delegate to the `post-reviewer` subagent (Opus, medium effort — defined in
`.claude/agents/post-reviewer.md`) rather than reviewing inline; it carries the
full check list and the fix/ask boundary. Run it **synchronously** — you need its
output before you can ask the author anything. Pass it:
- the target file path,
- the tag and category vocabularies from Step 1,
- the list of candidate posts for internal linking.

It edits the file in place for mechanical fixes and returns a report with a
numbered question list.

## Step 3 — Put the questions to the author
Use `AskUserQuestion` for the decisions the reviewer raised, with its proposed
options as the choices plus a sensible alternative. Batch related items — a
question per check area, not per finding — and cap it at four questions per
round; if there are more, take the highest-impact ones first and raise the rest
as plain text afterward.

Typical rounds:
- **Description** — offer the reviewer's rewrite vs. keeping the current one,
  when it's over 160 characters or weak.
- **Title** — offer a shorter phrasing when it's over ~60 characters.
- **Tags** — offer the proposed additions (multi-select) so the author picks
  which ones land.
- **Clarity** — quote each unclear sentence and ask what was meant. Prefer free
  text here: the author knows what happened on the trip and you don't. Never
  guess a fact to make a sentence read better.
- **Coords** — report the mismatch and ask for the right value; do not invent
  coordinates.

## Step 4 — Apply the answers
Make exactly the edits the author chose. Where they supplied a correction in
their own words, use their wording — reword only for grammar. Don't take an
answer about one sentence as licence to edit neighbouring ones.

## Step 5 — Report
Summarize:
- which file was reviewed,
- the mechanical fixes applied (so the author can spot them in `git diff`),
- the decisions applied from Step 3,
- anything still open — declined suggestions, unanswered questions, coordinates
  awaiting a value,
- whether a `/translate` run is needed, if PL/NL versions of this `post_id`
  already exist and the English text changed.

## Notes
- Only touch the reviewed file. Never edit sibling translations here.
- Never change `date`, `post_id`, `author`, `layout`, or image `src` paths.
- Preserve front-matter key order and the file's existing formatting, including
  the tab after `tags:` and blank-line spacing in the body.
- If the post is already clean, say so plainly and make no edits.

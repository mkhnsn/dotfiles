---
name: deck-copy
description: Rules for writing slide decks and presentations (pitch decks, reviews, talks, proposals) so they read as written by a person who knows the subject, not generated. Use when drafting, editing or reviewing slide text, headlines or speaker notes, in any format (Claude Slides artifacts, Keynote, Google Slides, Figma Slides, pptx, HTML, Markdown).
---

# Deck copy

A slide makes one claim and shows the evidence for it. The audience reads the
headline, glances at the evidence, then listens. Everything on the slide
serves that claim. The rest goes in the speaker notes, in the order the
presenter would say it.

Generated decks give themselves away with slogans, symmetrical structures and
importance words standing in for facts. The fix is specifics: numbers, names,
prices, dates, and what actually happens.

Builds on the `ui-copy` skill (lead with the point, cut, plain words) and the
catalog of tells at
https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing.

## Rules

1. **Headlines are claims, in a sentence.** "Car builders already pay $110–132
   for an app-set light controller", not "Market validation". A reader who sees only the
   headlines should get the whole argument.
2. **One claim per slide.** If the headline joins two claims (with "and", a
   semicolon or a second sentence), split the slide or move one claim to the
   body or the notes.
3. **Evidence, not adjectives.** Replace every "powerful", "seamless",
   "robust", "proven" or "unique" with the fact behind it: the spec, the
   price, the count, the source. If there's no fact, cut the word.
4. **No slogan formulas.** No "Not X, it's Y", "X, not Y" taglines, "It's not
   just A. It's B.", "Less X, more Y", or three-beat lists written for rhythm.
   State the claim directly. A contrast stays only when the audience actually
   holds the other belief, and then it's a plain sentence. A concrete analogy
   that names two real things is fine (see `references/investor-decks.md`).
5. **No importance words.** Cut "the differentiator", "game-changer",
   "unlock", "landscape", "ecosystem", "journey", "the future of",
   "revolutionize", "at the intersection of". Say what the thing does and
   let the audience judge.
6. **Plain verbs.** "Is", "has", "costs", "sells", "drives". Not "serves as",
   "boasts", "leverages", "empowers", "delivers".
7. **Name things.** Products, companies, prices, people, places, dates. "Four
   retrofit shops, RGB Halo Kits among them, sell it pre-wired" beats "a strong installer channel".
   Vague attribution ("experts say", "studies show") gets a name and a link,
   or goes.
8. **Bullets are fragments, parallel, few.** Three to five per slide, each
   under about eight words, no trailing periods. No bold lead-in followed by
   a colon on every bullet.
9. **Numbers carry units and sources.** "$149 proposed", "3.09M paid
   subscribers (Cricut Q4 FY25)". Mark proposals and estimates as such on the
   slide, once, in the source line.
10. **Speaker notes are talk, not a second slide.** Write them the way the
    presenter would say them: full sentences, first person plural is fine,
    the reasoning and caveats the slide left out. No headings or bullets.
11. **Say what's uncertain once, plainly.** "Prices are proposals, not
    decisions." Not a hedge on every line, and not "it's worth noting".
12. **No wrap-up slogans.** The last slide says what happens next and what
    you're asking for, with numbers and dates. No "The future is bright" or
    "Let's build it together".
13. **Sentence case, no emoji, no exclamation marks, no em dashes.** Use a
    comma, a colon or a new sentence. Ranges take an en dash: 2014–2026,
    $129–179.
14. **Read it aloud.** If the presenter wouldn't say it that way to a
    skeptical expert across a table, rewrite it.

**Don't cut the argument.** Specific and short must still be true: keep the
caveat that changes the decision (a competitor's beta feature, a price that's
a guess), and keep the source.

## Where things go

| Need                              | Put it                                     |
| --------------------------------- | ------------------------------------------ |
| The claim                         | The headline                               |
| The evidence                      | The body: a number, chart, table or image  |
| Where a figure came from          | A one-line source under the evidence       |
| Reasoning, caveats, the story     | Speaker notes                              |
| Full research and tables          | A linked doc (repo Markdown, appendix)     |

## Checking a deck

Read only the headlines in order. Do they make the argument? Then, per slide:

- Is the headline a claim with a verb?
- Does any phrase match a tell in `references/tells.md`? Rewrite it.
- Could a competitor put this sentence on their slide unchanged? Then it says
  nothing. Make it specific.
- Does every number have a unit and a source?
- Would the notes sound natural spoken aloud?

## References

Load these when the task needs them:

- `references/tells.md`: words, phrases and structures that read as
  generated, with what to write instead.
- `references/examples.md`: before and after rewrites, by pattern.
- `references/investor-decks.md`: slide order, the ask, traction, team and
  competition slides for decks that raise money.

## Extending

Add a topic as `references/<topic>.md` and list it under References with one
line on when to load it. Candidates: chart titles and captions, conference
talk decks, internal review decks. Keep the rules above
short and general.

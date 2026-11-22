# Product decks

Structure and copy for decks that show a product or prototype: what it is,
what it does, why it's useful. An investor deck argues that a company should
exist; if a deck spends its middle on market size, competitors and revenue,
it's an investor deck, so use `investor-decks.md`. For a product shown to
investors, follow `investor-decks.md` for the order and use this file for the
solution and product slides.

Structure and copy are drawn from the text of these pages, read in November
2026: Apple AirTag (https://www.apple.com/airtag/), Teenage Engineering OP-1
(https://teenage.engineering/products/op-1), Playdate (https://play.date/),
Elgato Stream Deck + (https://www.elgato.com/us/en/p/stream-deck-plus-black),
Adafruit QT Py RP2040 (https://www.adafruit.com/product/4900), SparkFun Thing
Plus ESP32 (https://www.sparkfun.com/sparkfun-thing-plus-esp32-wroom-usb-c.html),
Core77 on design presentations (https://www.core77.com/posts/20634) and
Loughborough on presentation boards (https://usability-net.lboro.ac.uk/?p=297).
The prototype-status slide follows gate reviews, where each gate ends in a
decision (https://null2one.pages.dev/insights/evt-dvt-pvt-decision-gates/).
The images on those pages weren't visible, so the Pictures section is
editorial judgment.

## Order

The main run is slides 1 to 12:

1. Hero: the product name, one tagline line, one big render
2. Who uses it and where, before any feature
3. What it is: the render with its inputs and outputs labeled
4. What it does: one use case per slide, titled by the job, product shown in use
5. How it works: one flow (set up, then run) and two or three app screens
6. Feature grid: short label plus one line each
7. The system: how several units and accessories fit together
8. Variants or colorways side by side
9. Scale: the product next to a hand, a coin or something everyone knows
10. Specs: one grouped table of values
11. Today vs. with it: what people use now, against the product
12. Where the prototype stands: what works, what's open, the decision needed

Business, cost, risks, roles and plans go after that, in an appendix or an
internal FAQ. Market size and competitor deep dives usually go nowhere.

## Headlines

- **Slides 1 to 10 take short headlines of 2 to 8 words**, in place of rule
  1's sentence claims: the product name, a noun ("Specs"), a job ("Voice-lit
  helmet") or a benefit. A benefit headline has a verb or names a thing, and
  isn't built for rhythm: "Lights that follow the beat", not "Sealed.
  Synced."
- **Slides 11 and 12, and everything after them, follow rule 1**: a claim in
  a sentence.
- **One tagline on the hero** may be a short run of two or three parallel
  phrases naming real actions: "Wire it. Tap it. Wear it." It's the only
  place rule 4's rhythm ban lifts. Negation and contrast forms ("Not X, it's
  Y", "Less X, more Y", "Not just A") still don't qualify.

## Body copy

- **One sentence, or none.** The picture carries the rest. A slide that needs
  a paragraph needs a better picture or a second slide.
- **Feature labels**: two to four words, then one line. Write the label in
  sentence case ("Syncs over radio"). Small uppercase type for eyebrows and
  labels is a style, set in CSS, not text typed in capitals.
- **Specs are values, not sentences**, grouped under headings with units:
  "3 pixel chains", "4 loads, up to 24 V", "60 × 20 mm".
- **Use-case titles name the job**: "Voice-lit helmet", "Prop weapon",
  "Full suit".
- **Numbers sit inside the line** they support ("about 60 mm across"). Their
  sources go in the slide's one-line source footer (rule 9).
- **Speaker notes are short**: what you'd say, in two to four sentences. Keep
  any caveat that changes the decision.

## Pictures

Every slide in the main run has a picture that makes its point without the
words:

- the hero render, large, on a plain background
- the product in use: on the costume, in the prop, on the wall
- a scale shot beside a hand or a coin
- callouts on a render instead of a bullet list of features
- the variant or color lineup
- app screens, drawn as mockups if the app doesn't exist yet, marked as
  mockups in the source line
- an exploded view for "what's inside"
- a simple flow diagram for how it works

Keep callouts few: about six on one render is a rule of thumb, not a
measured limit.

## Prototype status

Slide 12 has a claim headline and three short lists under their own
headings, not bold lead-ins:

- Works: what's built and measured
- Open: what isn't decided or tested yet
- Decide: the decision this meeting needs

## Checking a product deck

SKILL.md's "Checking a deck" applies, except that headlines on slides 1 to
10 are checked against this file, not for a verb, and the hero tagline is
checked against the Headlines section here, not `tells.md`.

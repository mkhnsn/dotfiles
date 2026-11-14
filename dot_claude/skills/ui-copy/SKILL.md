---
name: ui-copy
description: Rules for writing UI copy (labels, buttons, help text, notices, errors, confirmations, empty states). Use when writing, editing or reviewing any user-facing text in an app or site, including server error messages people see.
---

# UI copy

Text in the interface is part of the controls, not commentary on them. It
says what something is or what to do, in as few words as do the job. How it
works and why belong in help, behind a toggle, or in the docs.

Drawn from Shopify Polaris (content guidelines), the Microsoft Writing Style
Guide, GOV.UK content design and Apple's Human Interface Guidelines.

## Rules

1. **Lead with the action or the outcome.** The first words carry the
   meaning: "Export a zip to keep your work", not "To keep your work, you can
   export a zip".
2. **One short sentence of help, at most.** Under a heading or beside a
   control. More goes behind a "How this works" toggle or in the docs.
3. **No mechanism.** Don't explain how the system works. Say what the person
   gets.
4. **No edge cases up front.** Cover the common case. Exceptions go where
   they happen (an error, a notice on the affected item) or behind a toggle.
5. **One idea per sentence.** No semicolons. No chains of colons and clauses.
   Two short sentences beat one long one.
6. **Don't narrate.** Not "Someone shared this with you" or "The app will
   now…". State the fact: "Shared · read-only".
7. **Don't justify or hedge.** Say the consequence plainly: "Results recorded
   now may be inaccurate."
8. **Buttons are verbs, labels are nouns.** Headings name the thing: "Share
   links", not "Sharing your library with others".
9. **Errors say what happened and what to do.** "Couldn't reach the server.
   Your changes are saved here and sync when you're back online."
10. **Confirmations state the consequence once.** "Delete 'Shop' and its
    history for everyone in 'Makerspace'? This can't be undone."
11. **Empty states: what goes here, and one action.**
12. **Plain words, the person's words.** Code terms only where the person
    types them.
13. **Sentence case.** No trailing period on headings, buttons or labels.
    Numerals for numbers ("3 printers").
14. **Cut, then cut again.** Remove every word that doesn't change what the
    reader does next.

**Don't cut meaning.** Shorter must still be true and complete: keep who is
affected, what can't be undone, and what the person should do. "You left the
team" is wrong when an owner removed them.

## Where longer text goes

| Need                    | Put it                                         |
| ----------------------- | ---------------------------------------------- |
| What a control does     | Its label; a tooltip if the label can't say it |
| Why, or how it works    | A "How this works" toggle, or the docs         |
| What happens on failure | The error, when it happens                     |
| A one-off warning       | A notice on the affected item, not a paragraph |
| Reference material      | A dialog or the docs                           |

## Checking copy

Read each string and ask:

- Does the first phrase say what this is or what to do?
- Is there a semicolon, a colon chain, "so…", "but…", or a parenthetical
  aside? Split it or cut it.
- Does it explain how the system works? Move that out.
- Is it still true in every case the code allows?

## References

Load these when the task needs them:

- `references/examples.md`: before and after rewrites, by pattern.
- `references/patterns.md`: templates for errors, confirmations, empty
  states, notices and limits.

## Extending

To add to this guide, put a new topic in `references/<topic>.md` and list it
under References with one line on when to load it. Candidates: voice and
tone, glossaries per product, accessibility of text (link names, alt text),
numbers, dates and units, localization. Keep the rules above short and
general. Detail belongs in a reference file.

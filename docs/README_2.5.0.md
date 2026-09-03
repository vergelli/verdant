# README snippets for 2.5.0

Paste-ready text for the README and the ESOUI listing. Written in the
addon's voice; edit freely. Not shipped.

## One paragraph

Verdant 2.5.0 is the release where the graph starts talking back. Every
view now has a tab, every button a tooltip and a sound, and after a
recording the summary chip tells you how much of your healing landed,
how much overflowed, and whether an ultimate sat ready and unused. Hover
the chip for the full report, click it to copy it into group chat.

## What is new

**Six views, one tab strip.** EMS, SKILL, CRIT, OHEAL, BUFFS and TRIAGE
sit in a tab row under the controls. Click to jump, hover for a one-line
explanation of the view.

**OHEAL.** Effective healing stacked under the overflow, so the
proportion reads at a glance. The report splits the overflow into HoT
ticks landing on full targets (normal) and direct heals that overflowed
(the part you can work on).

**Ultimate rows.** One row per bar: the ultimate slotted on it, its icon,
the charge against that bar's own cost, bright gold once it is ready, a
white tick at each cast. Hover a row for the state at that moment.

**TRIAGE, rebuilt.** A donut of outcomes with `n% saved` in the centre,
a legend that counts and explains every class in five words, and below
it the episodes of the class you click, latest first, wheel to scroll.

**Healing report.** Hover the summary chip: landed vs overflow with a
small donut, HoT vs direct overflow, time an ultimate sat ready and
unused, casts and their spacing, when the peak was, the saves tally.
Click the chip to copy it as text.

**Session library.** Every saved night shows a ring of landed vs
overflowed healing next to its name.

**Your own categories.** In Unknown Contributions the picker ends with
"+ New category": name it, pick a colour, done. It survives logins.
Companion heals have their own colour now, and buffs no longer show up
in that list.

**Light Mode.** While recording, the window sheds its chrome and dims to
a configurable opacity; hover restores it.

**Buff watch.** Star a buff in the BUFFS view and a small banner counts
down before it drops.

**Grow-to-fill.** A fresh recording no longer starts as tiny bars on an
empty axis; the axis grows with the recording until it reaches the
configured window.

**Quality of life.** Record and Stop wear their icons, Flush is now New,
the compact bar shows a red dot while recording and its metric name is
clickable. Hover cards are solid, dark, gold-framed and drawn above
everything.

**Under the hood.** A new recording no longer inherits the previous
window. Stop no longer stutters: the autosave runs cooperatively over
the following frames. `/verdant hitch` lists frame stutters and whether
Verdant was busy in them, so a stutter can be blamed or cleared.

## Slash commands

```
/verdant          toggle the compact bar
/verdant graph    toggle the graph window
/verdant lib      open the session library
/verdant hitch    frame hitches seen, and whether Verdant was busy
/verdant help     this list
```

## Listing header (ESOUI)

Keep the AI disclosure line at the very top of the description, then the
dependency line (none), then the paragraph above. Changelog goes in the
Changelog tab, from `CHANGELOG.md`.

# Stamp Order — Implementation Plan (v2)

Updated Oct 19, 2026. Supersedes the Oct 9 plan. What changed: the core loop
is now **plan, then stamp**; puzzles are generated to have one answer;
mechanics arrive every few levels; the MVP is 60 levels in 4 worlds of 15.
Status markers: ✅ built in the MVP, ⏳ planned (not started).

## Core-loop prototypes (Oct 2026)

Playtesting v2 still felt flat: every level reduces to one procedure ("the
stamp you can see whole went last"), so extra mechanics only add steps. Two
alternative core loops are now playable from the main menu (**New modes**),
10 levels each, alongside the current game, to pick a direction by playing:

| | A · Free Stamp | B · Sticker Stack |
| --- | --- | --- |
| Loop | Drag stamps anywhere on the paper (tap to turn); some can be pressed twice. Recreate the target | Tap stickers nothing covers; they go to a 7-slot tray; three alike clear; a full tray loses |
| The thinking | Decomposition: which shape made which region, what hides underneath, then order | Lookahead: what's under the pile, keeping the tray from filling with singles |
| Generator | Keeps only pictures that can be made exactly one way (`FreeSolver.count_decompositions`) | Built backwards from a winning order, so every pile can be cleared |
| Code | `proto/free/`, `tools/generate_free.gd` | `proto/stack/` |

Decision pending playtests. Whichever wins replaces the core loop below.

## Framework

Godot 4.7 with GDScript, Compatibility renderer, portrait. One project exports
an Android AAB/APK and an iOS Xcode project. Unchanged from v1.

## Why v1 felt easy, and the fix

v1 let players press, compare and undo for free, and generated levels where
most stamps barely overlapped, so most orders won. Nothing had to be reasoned
out. v2 makes every solve a small deduction:

| Problem | Fix | Status |
| --- | --- | --- |
| Trial and error is free and instant | **Plan, then stamp**: queue the whole order, hit STAMP!, watch it play out. A failed run marks the first stamp that broke the picture. Editing the plan is free; failed runs cost a star | ✅ |
| Many orders win | Generator builds overlap **chains** and scores by the number of valid orders; the last puzzle of each world has exactly one | ✅ |
| Clues are big and obvious | Score rewards **sliver clues** (an order decided by 1–2 cells) and depth | ✅ |
| Perfect play is invisible | **Perfect seal** in the header that cracks on the first failed run, undo or hint | ✅ |
| Hints give the answer away | **Two-step hints**: first a "look here" ring on the target, then the stamp | ✅ |
| Solving leaves no trace | **Win replay** of the player's order with numbered layers | ✅ |
| One idea for 20 levels | **A new mechanic every 5 levels** for the first 35 levels, then combinations | ✅ (MVP set) |

## Rules (MVP)

1. The screen shows a blank paper canvas, the target picture and a tray of stamps.
2. Each stamp has a fixed shape, colour and spot (or a choice of spots / rotations).
3. Ink is opaque: a new stamp covers whatever is under it. The eraser presses bare paper.
4. Each stamp can be used at most once. **Spare** stamps are not in the picture.
5. Levels 1–4 are pressed live, one tap at a time, to teach layer reading.
   From level 5 on, the player builds a plan (bottom first) and hits STAMP!.
6. Undo, restart and plan edits are free. No move limit, no timer.
7. Stars: 3 for the first STAMP! with no hints, 2 after a failed run (or undo
   in live levels), 1 with a hint. Stars never block progress.

## Mechanics roadmap

One new idea every 4–5 levels: introduced alone in an easy level with a tip,
then mixed with what came before.

| # | Mechanic | What the player works out | Status | Introduced at |
| --- | --- | --- | --- | --- |
| 1 | Order (live pressing) | Which layer is on top | ✅ | 1 |
| 2 | Plan, then stamp | The whole order in advance | ✅ | 5 |
| 3 | Spare stamp | Which tray stamp is not in the picture | ✅ | 10 |
| 4 | Two spots | Where the stamp goes, not just when | ✅ | 16 |
| 5 | Eraser stamp | White holes are clues: what was cut, and when | ✅ | 21 |
| 6 | Twin colours | Which same-coloured stamp is on top, from shape alone | ✅ | 26 |
| 7 | Rotation | Which way it faces, from its edges | ✅ | 31 |
| 8 | Double stamp | One stamp pressed twice: both under and over something | ⏳ | v1.0 |
| 9 | Pre-inked paper | Which ink was already there and must be covered or kept | ⏳ | v1.0 |
| 10 | Clear ink | Blue over yellow makes green: colour shows order | ⏳ | later |
| 11 | Stencil | A mask must go down before the stamp it blocks | ⏳ | later |
| 12 | Mirror stamp | Left/right flips read from asymmetric shapes | ⏳ | later |
| 13 | Linked stamps | Pressing one also presses its partner | ⏳ | later |
| 14 | Sliding paper | The sheet shifts each press, so order changes position | ⏳ | later |
| 15 | Fog | Part of the target is hidden and must be inferred | ⏳ | later |

## MVP scope

The MVP is a 60-level test build for TestFlight and Google Play closed testing.
It answers one question: do testers keep playing past level 20?

| Feature | MVP | v1.0 | Later |
| --- | --- | --- | --- |
| Live pressing (tutorial), plan & stamp, win check | ✅ | Yes | |
| Undo, restart, stars, perfect seal | ✅ | Yes | |
| Two-step hints | ✅ unlimited | 3 free, more via rewarded ad | |
| Win replay with numbered layers | ✅ | Yes | Exploded layer view |
| Levels | ✅ 60 in 4 worlds | 90 in 6 worlds of 15 | Packs of 15–30 |
| Mechanics | ✅ #1–7 | + #8–9 | #10–15 |
| Menus, level select, gallery, settings, colourblind mode | ✅ | Yes | |
| Local save, analytics (incl. failed plan runs) | ✅ | Yes | Cloud save |
| Sound, haptics, juice | ✅ basic | Full pass | |
| Ads, remove-ads IAP, GDPR consent | No | Yes | |
| Daily puzzle | No | No | Yes |

## World plan (MVP)

Every world ends on a hand-made picture level. Mechanic introductions are easy.

| World | Levels | Stamps | New ideas | Theme |
| --- | --- | --- | --- | --- |
| 1 | 1–15 | 3–6 | Live order (1–4), plan & stamp (5), spare (10) | Garden |
| 2 | 16–30 | 4–7 | Two spots (16), eraser (21), twin colours (26) | Kitchen |
| 3 | 31–45 | 5–8 | Rotation (31), then mixes of everything | Night sky |
| 4 | 46–60 | 6–9 | Mastery: every mechanic combined | Toy box |

v1.0 adds worlds 5–6 (levels 61–90) with double stamp and pre-inked paper.

## Generator (v2)

1. Pick the stamps' press order first, then place each stamp so it partly
   overlaps the stamp pressed just before it (the chance grows with
   difficulty). Re-centre the composition on the paper.
2. Add the slot's mechanics: decoy spots, rotations, an eraser after the first
   two stamps, a twin colour, a spare (harder spares share a colour with a
   real stamp, so only the shape gives them away).
3. Reject: any used stamp showing fewer than 4 cells; an eraser cutting fewer
   than 4 cells of ink; a stamp that overlaps nothing; a spare that can be
   part of any solution; a decoy spot or a starting rotation that also solves.
4. Score: stamps + 3 × depth + 2 × sliver clues + 2 × twists − 3 × log2(valid orders).
5. Slots carry a difficulty 0–1. Harder slots only accept candidates with at
   most a few valid orders (one at the top). Pick by score percentile.
6. The level lab (`tools/level_lab.tscn`) reviews candidates; binned ones are
   never picked again.

## Milestones (updated)

1. ✅ Pipeline, core prototype, solver, generator, game flow, look and feel.
2. ✅ v2 core loop: plan & stamp, one-answer generator, mechanics #1–7, perfect
   seal, two-step hints, win replay.
3. ⏳ **Fun test with 5 people on the v2 loop.** Watch whether failed runs feel
   fair and whether players reach for "one more".
4. ⏳ Content pass: play all 60, bin weak ones in the level lab, regenerate.
5. ⏳ MVP test: closed testing with 15–20 testers; watch the quit points and
   failed-run counts per level.
6. ⏳ v1.0: mechanics #8–9, worlds 5–6, ads, remove-ads purchase, consent,
   store listing.

## Launch checklist

Unchanged from v1: a new personal Google Play account needs a closed test
with at least 12 testers opted in for 14 continuous days before production;
start it on the first day of the MVP test. Accounts, signing keys, privacy
policy, store listing, rating questionnaires and data-safety forms as in v1.

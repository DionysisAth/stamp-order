# Stamp Order

A chill puzzle game for Android and iOS. The player sees a finished picture made of overlapping coloured stamps and must press the stamps in the order that recreates it. Built with **Godot 4.7** and GDScript.

This is the **MVP** test build: 60 levels in 3 worlds, undo and restart, stars, hints, two-spot and rotation twists, a gallery wall, colourblind mode, local save, basic sound and haptics, and local analytics.

## Running it

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in the editor and press **F5**.

The project uses the Compatibility renderer, which suits a 2D game and works on the widest range of phones.

## Project layout

```
core/            shared "puzzle core", reusable for the next game
  autoload/      Save, Levels, Audio, Haptics, Analytics, Router (navigation)
  ui/            main menu, level select, gallery, settings, win panel, theme
  undo/          Command and UndoStack
game/            Stamp Order itself
  board_state.gd 16×16 canvas of colour ids; pure logic, no nodes
  stamp_def.gd   shape, size, colour and allowed placements of one stamp
  level.gd       level data; the target is rebuilt from the solution
  shapes.gd      vector stamp shapes; grid masks are sampled from them
  solver.gd      peels layers off the target: hints, solvability, analysis
  game_controller.gd, canvas_view.gd, stamp_button.gd   the play screen
levels/          world_1.json … world_3.json (generated, then committed)
tools/           editor-only: level generator, hand-made levels, level lab,
                 preview and screenshot renderers
tests/           headless unit tests and a UI smoke test
ci/              scripts used by GitHub Actions
```

Only press commands on the undo stack change the game state, so every move can be undone, and the solver, generator and tests reuse the same state classes without any scene.

## Levels

Levels 1 to 5 and every 10th "picture" level are hand-made (`tools/handmade_levels.gd`); the rest come from the generator, which builds hundreds of candidates per slot, rejects unreadable ones (any stamp showing fewer than 4 cells, decoy spots or rotations that also solve the level), scores them and picks one to fit the world's difficulty curve.

```sh
# Rebuild levels/*.json (deterministic; CI checks the committed files match)
godot --headless --script res://tools/generate_levels.gd

# Also dump all scored candidates for review in tools/level_lab.tscn
godot --headless --script res://tools/generate_levels.gd -- --candidates

# Contact sheets of every target picture
godot --headless --script res://tools/render_previews.gd -- /tmp/previews
```

In the level lab, `←`/`→` browse, `K` keeps, `B` bins (the generator never picks a binned candidate again) and `P` presses the solution one stamp at a time.

## Tests

```sh
godot --headless --import
godot --headless --script res://tests/run_tests.gd   # unit tests
godot --headless --script res://tests/smoke_ui.gd    # opens every screen and plays all 60 levels
```

## CI (GitHub Actions)

`.github/workflows/android.yml` runs on every push to `main`, on pull requests and on demand:

| Job | What it does |
| --- | --- |
| Tests | Unit tests, UI smoke test, and a check that `levels/` matches the generator |
| Build debug APK | Exports `stamp-order-debug.apk` (arm64 + x86_64) and uploads it as an artifact |
| Emulator startup test | Boots Android emulators (API 30 and 34), installs the APK, launches it and fails if the main menu never appears, the app stops running, or logcat shows a crash, ANR or script error. Logcat and a screenshot are uploaded |
| Publish debug APK | On pushes to `main`, once both emulator tests pass, uploads the APK to the [latest-debug](https://github.com/DionysisAth/stamp-order/releases/tag/latest-debug) pre-release. Direct download, no sign-in: https://github.com/DionysisAth/stamp-order/releases/download/latest-debug/stamp-order-debug.apk |
| Build Play Store AAB | Gradle build of the release `.aab` (arm64 + armv7) for Google Play, with the version code set from the run number. Skipped on pull requests |

To sign the AAB for Google Play, add these repository secrets; without them the AAB is signed with a throwaway key and cannot be uploaded:

- `ANDROID_KEYSTORE_BASE64`: your upload keystore, `base64 -w0 upload.keystore`
- `ANDROID_KEYSTORE_PASSWORD`: the keystore (and key) password
- `ANDROID_KEY_ALIAS`: the key alias

## Analytics

Events (`level_start`, `level_complete`, `hint_used`, `undo_count`, `quit_mid_level`) are appended to `user://analytics.jsonl` on the device. To send them to a backend, set the project setting `stamp_order/analytics/endpoint` to a URL that accepts POSTed JSON arrays.

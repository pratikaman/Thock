# Repository guide

## Project

Thock is a macOS 14+ app that plays a sound on keyboard presses. It uses SwiftUI,
AppKit, AVFoundation, and a listen-only CoreGraphics event tap. There are no
third-party dependencies, Xcode project, or Swift package manifest; `build.sh`
compiles `Sources/*.swift` directly with `swiftc` in Swift 5 mode.

## Layout

- `Sources/App.swift`: entry point, main window, menu bar scene, and floating pill panel.
- `Sources/Model.swift`: shared observable state, preferences, sound presets/imports,
  Input Monitoring state, login registration, and keystroke counts.
- `Sources/Engine.swift`: audio decoding/shaping, playback voice pool, keyboard event
  tap, and the `SelfTest` runner.
- `Sources/Views.swift`: theme helpers and SwiftUI pages, controls, menu, and pill.
- `Resources/`: bundled CAF sounds, Figtree/EB Garamond fonts and licenses, and icons.
- `Tools/icon.swift`: app icon renderer.
- `Info.plist`: bundle identity, version, minimum OS, and font registration.
- `build.sh`: compilation, resource copying, self-tests, signing, and optional install.

## Build and validation

Run from the repository root on macOS with Apple's command-line developer tools:

```sh
./build.sh                                  # Build, self-test, and sign build/Thock.app
build/Thock.app/Contents/MacOS/Thock --selftest # Re-run tests in the existing bundle
open build/Thock.app                        # Launch for manual UI/audio checks
```

`./build.sh --install` also stops running Thock processes and replaces
`/Applications/Thock.app`; use it when installation is part of the requested work.
The default signing identity is `Pratik Dev Signing`, overridable with
`THOCK_SIGN_IDENTITY`. The script falls back to ad-hoc signing if the identity is
unavailable. A stable signing identity helps preserve Input Monitoring permission
across rebuilds.

For code changes, run `./build.sh`. The existing self-tests cover preset decoding,
normalization and attack timing, custom clip trimming/duration, silent-file rejection,
and key/modifier/repeat filtering. Extend `SelfTest` for relevant engine regressions.
There is no separate test target or configured lint command. Documentation-only
changes do not require rebuilding.

For UI or playback changes, manually check the affected flow; self-tests do not
exercise live audio output, global keyboard access, or SwiftUI interaction. Relevant
checks include preview/selection, pause/resume, volume, custom imports, menu bar
controls, and modifier/repeat settings.

Engine logs can be inspected with:

```sh
log stream --predicate 'subsystem == "com.pratikaman.thock"'
```

## Development constraints

- Match the existing four-space indentation, naming, and small SwiftUI components.
  Reuse the color and font helpers in `Views.swift`.
- The UI uses a light keyboard-workbench theme: cool gray/white surfaces, cobalt
  accents, Avenir Next headings/body text, and Menlo labels. Keep top navigation,
  the keyboard playground, and the compact typing meter visually consistent.
- Preserve macOS 14 compatibility and the direct `swiftc` build unless a task
  explicitly calls for a build-system change.
- Keep the event-tap callback fast. Queue audio work on the player's dedicated
  queue and dispatch observable UI updates to the main queue.
- Preserve the privacy model: observe key events to trigger sounds and counts;
  do not record typed text or keystroke sequences. Keep the tap listen-only.
- Input Monitoring permission is granted by the user in System Settings. Do not
  change privacy settings or bypass Secure Input; suppressed events are expected
  while Secure Input is active.
- Preferences live in `UserDefaults`; imported sounds live in
  `~/Library/Application Support/Thock/Sounds`. Avoid deleting user data during
  development or validation.
- Audio clips are shaped to mono 48 kHz, normalized, and capped at two seconds.
  Preserve those assumptions when changing decoding or playback.
- Keep bundled filenames consistent with `Presets` and resource-copy steps.
  Bubble uses `/System/Library/Sounds/Pop.aiff`; other presets are bundled CAF files.
- Keep font licenses and sound attribution when changing assets. Build output
  belongs in the ignored `build/` directory.

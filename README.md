# Thock

A Mac app that plays a sound every time you press a key: a keyboard click, a typewriter, a gunshot, a meow, a bark, a quack, or any audio file you drop in.

Needs macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`). You don't need the full Xcode.

## Install with an AI agent

Paste this into Claude Code, Codex, Cursor, or any coding agent that can run terminal commands:

```text
Install Thock, a macOS app that plays a sound on every keystroke, from https://github.com/pratikaman/Thock.
1. Check that `swiftc` works. If it doesn't, run `xcode-select --install` and wait for me to finish the installer.
2. Clone the repo into ~/Thock (or pull if it's already there) and run `./build.sh --install` from inside it.
   The build runs a self-test and must end with "installed /Applications/Thock.app". If it fails, show me the error.
3. Open /Applications/Thock.app.
4. Tell me to allow Thock under System Settings → Privacy & Security → Input Monitoring
   (and to click "Quit & Reopen" if macOS asks). Don't change any privacy settings yourself.
```

## Install by hand

```sh
git clone https://github.com/pratikaman/Thock.git && cd Thock
./build.sh            # build/Thock.app (runs the self-test first)
./build.sh --install  # also copies it to /Applications
```

The first time, allow **Input Monitoring** (System Settings → Privacy & Security). Thock uses a listen-only event tap: it sees *that* a key went down, never what you typed, and it can't block or change input. Password fields are hidden from it by macOS.

- **Sounds**: 7 presets, plus your own sounds (any audio format macOS can read). Custom files are copied to `~/Library/Application Support/Thock/Sounds`. Each clip gets its leading silence trimmed and is normalized and capped at 2 s, so every key lands on the attack.
- **Settings**: volume, modifier keys, key repeat, the floating typing pill, and open at login.
- **Menu bar**: on/off switch and a sound picker. Closing the window keeps Thock running there.

## Credits

Sound clips are trimmed from [BigSoundBank](https://bigsoundbank.com/licenses.html) recordings by Joseph Sardin, released royalty-free (CC0-equivalent, no attribution required):
keyboard `#1733` Slow Keyboard · typewriter `#2842` Typewriter, Key · gunshot `#0438` Shot in .357 Magnum ·
meow `#0494` Little Meow of a Cat #1 · bark `#2352` Old dog barking #1 · quack `#0276` Ducks.
Bubble is macOS's built-in `Pop.aiff`, read at runtime.

Fonts: [Figtree](https://github.com/erikdkennedy/figtree) and [EB Garamond](https://github.com/octaviopardo/EBGaramond12), both under the SIL Open Font License (licence files are in `Resources/Fonts`). The UI takes its look from Wispr Flow.

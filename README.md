<p align="center"><img src="Resources/AppIcon.png" width="128" alt="Thock app icon"></p>

<h1 align="center">Thock</h1>

Hear a sound every time you press a key on your Mac. Pick a keyboard click, a typewriter, a bubble pop, a gunshot, a meow, a woof or a quack, or add a sound of your own.

## Install

Copy this into any AI agent that can use your terminal (Claude Code, Codex, Cursor…) and it will set Thock up for you:

```text
Install Thock on my Mac from https://github.com/pratikaman/Thock. Clone it, run ./build.sh --install, then open /Applications/Thock.app. If swiftc is missing, run xcode-select --install first and wait for me to finish. Once it's open, tell me to allow Thock under System Settings → Privacy & Security → Input Monitoring. Don't change privacy settings yourself.
```

### Or install it yourself

1. Open **Terminal** and run `xcode-select --install` to get Apple's free developer tools. Skip this if you already have them.
2. Download Thock and build it:
   ```sh
   git clone https://github.com/pratikaman/Thock.git
   cd Thock
   ./build.sh --install
   ```
3. Open **Thock** from your Applications folder.

Needs macOS 14 or newer.

## Using it

- When asked, allow Thock under **Input Monitoring**. It only knows that a key was pressed, never what you typed.
- Choose a sound on the **Sounds** page, or drop in your own.
- Thock lives in the menu bar, so you can pause it or switch sounds at any time.

Sounds from [BigSoundBank](https://bigsoundbank.com), free to use. Fonts: Figtree and EB Garamond.

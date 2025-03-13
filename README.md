<a href="https://github.com/artginzburg/MiddleClick-Sonoma/releases">
  <img align="right" src="https://img.shields.io/github/downloads/artginzburg/MiddleClick-Sonoma/total?color=teal" title="GitHub All Releases">
</a>

<div align="center">
  <h1>
    MiddleClick <img align="center" height="80" src="MiddleClick/Images.xcassets/AppIcon.appiconset/mouse128x128.png">
  </h1>
  <p>
    <b>Emulate a scroll wheel click with three finger Click or Tap on MacBook trackpad and Magic Mouse</b>
  </p>
  <p>
    with <b>macOS</b> Sonoma<a href="https://www.apple.com/macos/sonoma/"><sup>14</sup></a> support!
  </p>
  <br>
</div>

<img src="demo.png" width="55%">

<h2 align="right">:mag: Usage</h2>

<blockquote align="right">

It's more than just `⌘`+click

</blockquote>

<p align="right">

`System-wide` · close tabs by middleclicking on them

</p>

<p align="right">

`In Safari` · middleclicking on a link opens it in the background as a new tab

</p>

<p align="right">

`In Terminal` · paste selected text

</p>

<br>

## Install

### Via :beer: [Homebrew](https://brew.sh) (Recommended)

```ps1
brew install --cask --no-quarantine middleclick
```

> Check out [the cask](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/m/middleclick.rb) if you're interested

### <a href="https://github.com/artginzburg/MiddleClick-Sonoma/releases/latest/download/MiddleClick.zip">Direct Download · <img align="center" alt="GitHub release" src="https://img.shields.io/github/release/artginzburg/middleclick-Sonoma?label=%20&color=gray"></a>

<br>

### Hide Status Bar Item

1. Holding `⌘`, drag it away from the status bar until you see a :heavy_multiplication_x: (cross icon)
2. Let it go

> To recover the item, just open MiddleClick when it's already running

## Preferences

### Number of Fingers

- Want to use 4, 5 or 2 fingers for middleclicking? No trouble. Even 10 is possible.

```ps1
defaults write art.ginzburg.MiddleClick fingers 4
```

> Default is 3

### Allow to click with more than the defined number of fingers.

- This is useful if your second hand accidentally touches the touchpad.
- Unfortunately, this does not serve as a palm rejection technique for huge touchpads.

```ps1
defaults write art.ginzburg.MiddleClick allowMoreFingers true
```

> Default is false, so that the number of fingers is precise

### Tapping preferences

#### Max Distance Delta

- The maximum distance the cursor can travel between touch and release for a tap to be considered valid.
- The position is normalized and values go from 0 to 1.

```ps1
defaults write art.ginzburg.MiddleClick maxDistanceDelta 0.03
```

> Default is 0.05

#### Max Time Delta

- The maximum interval in milliseconds between touch and release for a tap to be considered valid.

```ps1
defaults write art.ginzburg.MiddleClick maxTimeDelta 150
```

> Default is 300

## Building from source

1. Clone the repo
2. Run `make`
3. You'll get a `MiddleClick.app` in `./build/`

## Credits

Created by [Clément Beffa](https://clement.beffa.org/),<br/>
fixed by [Alex Galonsky](https://github.com/galonsky) and [Carlos E. Hernandez](https://github.com/carlosh),<br/>
revived by [Pascâl Hartmann](https://github.com/LoPablo),<br/>
maintained by [Arthur Ginzburg](https://github.com/artginzburg)

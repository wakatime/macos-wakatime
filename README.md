# xcode-wakatime

Mac system tray app for automatic time tracking and metrics generated from your Xcode activity.

## Install

1. Download the [latest release](https://github.com/wakatime/macos-wakatime/releases/latest/download/WakaTime.zip).
2. Move `WakaTime.app` into your `Applications` folder, and run `WakaTime.app`.
3. Enter your [WakaTime API Key][api key], then press `Save`.
4. Use Xcode like normal and your coding activity will be displayed on your [WakaTime dashboard](https://wakatime.com)

## Usage

Keep the app running in your system tray, and your Xcode usage will show on your [WakaTime dashboard](https://wakatime.com).

If you’re prompted to enter your API Key, you can find that [here](https://wakatime.com/api-key).

## Building from Source

1. Run `xcodegen` to generate the project.
2. Open the project with Xcode.
3. Click Run (⌘+R) or Build (⌘+B).

If you run into Accessibility problems, try running `sudo tccutil reset Accessibility`.

## Uninstall

To uninstall, move `WakaTime.app` into your mac Trash.

If you don’t use any other WakaTime plugins, run `rm -r ~/.wakatime*`.

## SwiftLint

To fix the formatting warning you should run `swiftlint --fix`

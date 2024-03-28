# macos-wakatime

Mac system tray app for automatic time tracking and metrics generated from your Xcode activity.

## Install

1. Download the [latest release](https://github.com/wakatime/macos-wakatime/releases/latest/download/macos-wakatime.zip).
2. Move `WakaTime.app` into your `Applications` folder, and run `WakaTime.app`.
3. Enter your [WakaTime API Key][api key], then press `Save`.
4. Use Xcode like normal and your coding activity will be displayed on your [WakaTime dashboard][dashboard]

## Usage

Keep the app running in your system tray, and your Xcode usage will show on your [WakaTime dashboard][dashboard].

## Building from Source

1. Run `xcodegen` to generate the project.
2. Open the project with Xcode.
3. Click Run (⌘+R).

If you run into Accessibility problems, try running `sudo tccutil reset Accessibility`.

## Uninstall

To uninstall, move `WakaTime.app` into your mac Trash.

If you don’t use any other WakaTime plugins, run `rm -r ~/.wakatime*`.

## Supported Apps

Before requesting support for a new app, first check the [list of supported apps][supported apps].

## SwiftLint

To fix linter warning(s), run `swiftlint --fix`.

## Contributing

Pull requests and issues are welcome!
See [Contributing][contributing] for more details.
The main thing to know is we require specific branch name prefixes for PRs:

- `^major/.+` - `major`
- `^feature/.+` - `minor`
- `^bugfix/.+` - `patch`
- `^docs?/.+` - `build`
- `^misc/.+` - `build`

Many thanks to all [contributors][authors]!

Made with :heart: by the WakaTime Team.

[api key]: https://wakatime.com/api-key
[dashboard]: https://wakatime.com/
[contributing]: CONTRIBUTING.md
[authors]: AUTHORS
[supported apps]: https://github.com/wakatime/macos-wakatime/blob/main/WakaTime/Watchers/MonitoredApp.swift#L3

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

WakaTime for Mac can track the time you spend in any app on your mac. It’s a catch-all when we don’t have a plugin for your IDE or app.

We add support for specific apps when a custom category, project, or entity type is necessary.
For example, when Slack needs the `communicating` category or Figma needs the `designing` category.
Only request support for a new app when it needs a custom category, or we can detect the project from the window title.

Before requesting support for a new app, first check the [list of supported apps][supported apps].

## Contributing

Pull requests and issues are welcome!
See [Contributing][contributing] for more details.
Many thanks to all [contributors][authors]!

Made with :heart: by the WakaTime Team.

[api key]: https://wakatime.com/api-key
[dashboard]: https://wakatime.com/
[contributing]: CONTRIBUTING.md
[authors]: AUTHORS
[supported apps]: https://github.com/wakatime/macos-wakatime/blob/main/WakaTime/Watchers/MonitoredApp.swift#L3

# Contributing

## Setup

This project depends on the [xcodegen](https://github.com/yonaskolb/XcodeGen?tab=readme-ov-file#installing) command line tool.

```bash
git clone git@github.com:wakatime/macos-wakatime.git
cd macos-wakatime
xcodegen
```

Then open the `WakaTime.xcodeproj` in [Xcode 15.2](https://developer.apple.com/services-account/download?path=/Developer_Tools/Xcode_15.2/Xcode_15.2.xip).
Currently there’s a bug in new Swift compiler versions, so the largest Xcode version working with this app is 15.2.

## Branches

This project currently has two branches

- `main` - Default branch for every new `feature` or `fix`
- `release` - Branch for production releases and hotfixes

## Testing and Linting

Build with `Xcode` before creating any pull requests, or your PR won’t pass the automated checks.

## SwiftLint

To fix linter warning(s), run `swiftlint --fix`.

## Branching Strategy

We require specific branch name prefixes for PRs:

- `^major/.+` - `major`
- `^feature/.+` - `minor`
- `^bugfix/.+` - `patch`
- `^docs?/.+` - `build`
- `^misc/.+` - `build`

More info at [wakatime/semver-action](https://github.com/wakatime/semver-action#branch-names).

## Pull Requests

- Big changes, changes to the API, or changes with backward compatibility trade-offs should be first discussed in the Slack.
- Search [existing pull requests](https://github.com/wakatime/macos-wakatime/pulls) to see if one has already been submitted for this change. Search the [issues](https://github.com/wakatime/macos-wakatime/issues?q=is%3Aissue) to see if there has been a discussion on this topic and whether your pull request can close any issues.
- Code formatting should be consistent with the style used in the existing code.
- Don't leave commented out code. A record of this code is already preserved in the commit history.
- All commits must be atomic. This means that the commit completely accomplishes a single task. Each commit should result in fully functional code. Multiple tasks should not be combined in a single commit, but a single task should not be split over multiple commits (e.g. one commit per file modified is not a good practice). For more information see <http://www.freshconsulting.com/atomic-commits>.
- Each pull request should address a single bug fix or feature. This may consist of multiple commits. If you have multiple, unrelated fixes or enhancements to contribute, submit them as separate pull requests.
- Commit messages:
  - Use the [imperative mood](http://chris.beams.io/posts/git-commit/#imperative) in the title. For example: "Apply editor.indent preference"
  - Capitalize the title.
  - Do not end the title with a period.
  - Separate title from the body with a blank line. If you're committing via GitHub or GitHub Desktop this will be done automatically.
  - Wrap body at 72 characters.
  - Completely explain the purpose of the commit. Include a rationale for the change, any caveats, side-effects, etc.
  - If your pull request fixes an issue in the issue tracker, use the [closes/fixes/resolves syntax](https://help.github.com/articles/closing-issues-via-commit-messages) in the body to indicate this.
  - See <http://chris.beams.io/posts/git-commit> for more tips on writing good commit messages.
- Pull request title and description should follow the same guidelines as commit messages.
- Rebasing pull requests is OK and encouraged. After submitting your pull request some changes may be requested. Prefer using [git fixup](https://git-scm.com/docs/git-commit#Documentation/git-commit.txt---fixupltcommitgt) rather than adding orphan extra commits to the pull request, then do a push to your fork. As soon as your PR gets approved one of us will merge it by rebasing and squashing any residuary commits that were pushed while reviewing. This will help to keep the commit history of the repository clean.

## Troubleshooting

If you have trouble building off `main` branch, try:

* close Xcode
* `rm -rf ~/Library/Developer/Xcode/DerivedData/WakaTime*`
* `rm -rf ./WakaTime.xcodeproj`
* `xcodegen`
* Open the project in Xcode
* Under `Signing & Capabilities`, set your `Team`

To read local user preferences, run:

    defaults read macos-wakatime.WakaTime

Any question join us on [Slack](https://wakaslack.herokuapp.com/).

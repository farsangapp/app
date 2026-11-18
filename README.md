<img src="assets/icon.svg" width="64" height="64" alt="">

# Farsang

Created in [T3 Code](https://t3.codes).

## Build and test

Requirements: Xcode 26 or newer with the iOS and watchOS simulator runtimes, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild test -scheme Farsang -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

- `Farsang.xcodeproj` is generated from `project.yml` and git-ignored. Rerun `xcodegen generate` after changing `project.yml` or adding files.
- The `Farsang` scheme builds both apps and runs the `FarsangCore` tests. To build only the watch app: `xcodebuild build -scheme Farsang -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO`.
- To run an app from Xcode, pick the `FarsangPhone` or `FarsangWatch` scheme.
- `Packages/FarsangCore` holds the pure logic (no UI) and also tests with `swift test` from that folder.
- Signing: set your own development team in Xcode locally. Never commit a team ID.

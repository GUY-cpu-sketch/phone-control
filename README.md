# Phone Control

Mac-free iOS screen viewer + web dashboard.

## Build
GitHub Actions uses a macOS runner and Xcode 27. The workflow generates the Xcode project with XcodeGen and builds an unsigned app artifact. Device installation requires Apple signing credentials.

## Important iOS limitation
A normal iOS app can stream its own/system-captured screen with Apple's screen capture APIs after user approval, but it cannot inject arbitrary touch events into other apps or the Home Screen. Remote commands are therefore scoped to this app.

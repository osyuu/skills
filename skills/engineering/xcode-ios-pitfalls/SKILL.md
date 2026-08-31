---
name: xcode-ios-pitfalls
description: Xcode / iOS silent failures: BUILD SUCCEEDED and green tests, then the install fails, an entitlement quietly does nothing, or a CLI is refused by TCC. Use when touching project.yml, Info.plist, entitlements, App Groups, code signing, or simulator-vs-device builds — and when a build will not install, or persistence vanishes on relaunch. 也認 裝不上實機 / entitlement 沒作用.
---

# Xcode / iOS Build and Signing Traps

Three traps share one shape: **silent failure**. Nothing is said at compile time or in the test
run; the failure lands at install time, or at runtime somewhere that prints no error.

**Walk all three before concluding.** Their symptoms are indistinguishable until read — each
one looks like "the build succeeded but something is wrong".

## 1. A hand-written Info.plist missing `CFBundleIdentifier`

Once `GENERATE_INFOPLIST_FILE: NO` is set, Xcode stops synthesising every `CFBundle*` key —
**you now own all of them**. With `CFBundleIdentifier` missing, compilation succeeds, signing
succeeds, `xcodebuild` returns `BUILD SUCCEEDED`, and **the install is what fails**:

```
CoreDeviceError 3000: ... not a valid bundle
```

The message names the bundle, not the key that is missing.

Keep the generated `*.xcodeproj` out of version control and commit the XcodeGen `project.yml`
instead. A checked-in project file plus a generator writing the same targets means the next
regeneration silently discards whichever edits were made in Xcode.

## 2. Simulator builds without an account: ad-hoc automatic signing

Set `CODE_SIGN_STYLE: Automatic` and leave `DEVELOPMENT_TEAM` empty — simulator build, test and
run all work. A team is only needed to go to a real device.

**Never reach for `CODE_SIGNING_ALLOWED=NO`.** What it turns off is signing, and **entitlements
are embedded at signing time** — App Groups, Keychain sharing and background modes are stripped
with it. What follows is silent: **writes raise nothing, the data is gone on relaunch, and unit
tests stay green** (they cover pure logic and never reach the container).

In a project with App Groups, this has to list a container:

```sh
xcrun simctl get_app_container booted <bundle-id> groups
```

## 3. macOS CLI using a protected framework: embed the plist in the executable

CoreBluetooth, camera, microphone and location all need a usage description, and usage
descriptions live in Info.plist — **a command-line executable has no bundle, so it has no
plist**. TCC does not prompt; it refuses.

Embed the plist into the executable itself, with the linker:

```
-sectcreate __TEXT __info_plist <path/to/Info.plist>
```

## Skip

Pure Swift with no Xcode build surface (SwiftPM libraries, server-side), and the Dart half of a
Flutter project — that is `flutter-dart-code-review`. The iOS runner's signing and plist still
fall under this file.

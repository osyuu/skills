---
name: xcode-ios-pitfalls
description: Xcode silent failures, where the toolchain reports success and the failure lands later. Use when running xcodebuild or simctl; when editing entitlements, signing or the bundle ID; or when a green build or test misbehaves at runtime. 也認 entitlement 沒作用. Not for server-side Swift.
---

# Xcode Silent Failures

Every trap here is a **silent failure**: `BUILD SUCCEEDED`, green tests, or a clean install, and the
failure lands later, somewhere that prints nothing, or with an error that points somewhere else.
A plausible first hypothesis is the usual way to miss one. Before you settle on a cause, check
every entry below whose symptom matches.

When asked to check a project for these traps, apply each entry to the project you were given.
Report the ones that apply, each with the file and line, or the command, that shows it.
"None apply" is a valid report. Don't fix anything unless asked.

## Signing and identity

To build and test on the simulator without an account, keep signing on: `CODE_SIGN_STYLE:
Automatic` with `DEVELOPMENT_TEAM` empty (ad-hoc signing). A team is needed only for a real
device.

**Never `CODE_SIGNING_ALLOWED=NO`**, even on a command that only compiles: build commands get
reused to test and run. It is the reflexive way through, and **entitlements are embedded at
signing time**: turning signing off strips App Groups, Keychain sharing and background modes.
Writes raise nothing, the data is gone on relaunch, and unit tests stay green because they never
reach the container.

In a project with App Groups, this must list a container. If it lists nothing, the build was
signed without its entitlements:

```sh
xcrun simctl get_app_container booted <bundle-id> groups
```

**The bundle ID is the app's identity.** Changing it cuts the app off from the permissions it was
granted, its App Group container and its keychain items. To tell two builds apart on the home
screen, change `CFBundleDisplayName` only.

## Build caches

- **UI tests fail with `Lost connection to the application`, and no new `.ips` crash report
  appears** in `~/Library/Logs/DiagnosticReports`. The missing report points away from an app
  crash; the usual cause is stale DerivedData. Give each checkout its own `-derivedDataPath` and
  clean that directory. Never glob-delete `DerivedData/<Name>-*`: other worktrees have live
  builds in there.
- **A change inside a local package (`path:` dependency) doesn't take effect.** The app's
  incremental build can skip rebuilding the package. Clean this checkout's DerivedData and build
  again. A path dependency also writes no `Package.resolved`, so nothing records which package
  commit a build used, and a mismatch builds without a warning.

## Simulator

- **A notification-permission alert appears on every launch and survives `simctl uninstall`
  and `simctl privacy … reset all`.** Only erasing the device clears it: shut it down, then
  `xcrun simctl erase <device>`. Don't request authorization in demo or screenshot mode, and
  erase before taking screenshots on a simulator that has run the test suite.

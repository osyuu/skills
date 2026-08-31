---
name: flutter-dart-code-review
description: Flutter/Dart code review checklist, library-agnostic across state management (BLoC, Riverpod, Provider, GetX, MobX, Signals), routing and DI. Use when reviewing Flutter or Dart code, or when asked to find anti-patterns, crash and leak risks, or to vet code before merging. It supplements the Standards axis of mattpocock-skills:code-review rather than replacing its two-axis review, so run that one first. 也認 審查 / 檢查 Flutter 程式碼 / Flutter コードレビュー. Skip for pure backend or CLI Dart with no Flutter surface, and for writing new code rather than reviewing existing code.
---

# Flutter/Dart Code Review

## This supplements the two-axis review, it does not replace it

**This is the language-specific half of `mattpocock-skills:code-review`'s Standards axis.**
That skill pins a fixed point and runs **two** axes in parallel — Standards (its baseline is
12 Fowler smells, zero Flutter/Dart entries) and Spec (what the spec asked for and the diff
missed, what the diff added beyond it, what looks done but is wrong).

**Run `code-review` first**, then walk Flutter/Dart with this file.

Running only this file **drops the Spec axis entirely**, and a long, detailed checklist report
looks exactly like a thorough review. That failure has no visible symptom.

## Use / Skip

**Use** when reviewing Flutter/Dart code — a PR, a widget, a feature branch, or a whole app —
or when asked to find anti-patterns, smells, crash or leak risks, or to vet code before merging.

**Skip** for pure backend, API, database, or DevOps work, and for general Dart CLI code with no
Flutter surface.

## Severity triage — the review order

Don't walk the sections in numeric order. Lead with what causes crashes, data leaks, or
exclusion; descend to polish. Report findings highest-severity first.

| Severity | Cover these first | Why |
|----------|-------------------|-----|
| **CRITICAL** | §9 Security · §12 Error handling (global capture, graceful degradation) · §4 `mounted`-after-`await`, subscription and timer disposal — that one is in `references/state-and-performance.md` | Hardcoded secrets, use-after-`await` crashes, and leaks ship real incidents |
| **HIGH** | §7 Accessibility (contrast, 48×48 targets, colour not the sole signal) · §5 Performance (build() cost, list virtualization, rebuilds) · §4 state shape (impossible states, exhaustive async) · §3 build-method complexity · §8 Platform (small-screen overflow, back navigation, declared permissions) | User-visible breakage and jank; whole classes of bugs made unrepresentable |
| **MEDIUM** | §2 Dart pitfalls · §3 const/keys/theming · §11 Navigation · §14 DI · §13 i18n · §6 Testing | Correctness and maintainability; degrade slowly, not acutely |
| **LOW** | §1 Project health · §10 Dependencies · §15 Static analysis config · remaining §5 micro-optimizations | Hygiene and tooling; real but rarely urgent |

Severity is contextual — a hardcoded colour is LOW in a prototype, HIGH in a themed design
system. The table is the default lead order, not a rigid rank.

**Done when every section the diff touches has been walked and every finding carries a
severity.** A review that stops at the first file it opened reads exactly like a complete one.

## Where the rest of the checklist lives

Two of the three CRITICAL entries are inline below; §4's disposal rules are not, so load
`references/state-and-performance.md` before starting a CRITICAL pass. Otherwise load the
reference whose branch the diff actually touches — loading all four is the same as having one
long file again.

- **`references/state-and-performance.md`** — §4 state management (all solutions), §5
  performance, and the state-solution quick reference. Reach for it when the diff touches
  providers, notifiers, streams, subscriptions, rebuilds, or list rendering.
- **`references/widgets-and-ui.md`** — §3 widget best practices, §7 accessibility, §8
  platform differences. Reach for it when the diff touches widget trees, layout, theming, or
  anything the user sees.
- **`references/dart-tests-and-tooling.md`** — §1 project health, §2 Dart language pitfalls,
  §6 testing, §10 dependencies, §15 static analysis. Reach for it when the diff touches
  `async`/`await`, null handling, collection or string idioms, `pubspec.yaml`,
  `analysis_options.yaml`, tests, or dependency versions.
- **`references/navigation-i18n-di.md`** — §11 navigation, §13 i18n, §14 dependency
  injection. Reach for it when the diff touches routes, deep links, translated strings, or
  service registration.

---

## 9. Security

### Secure storage:
- [ ] Sensitive data (tokens, credentials) stored using platform-secure storage (Keychain on iOS, EncryptedSharedPreferences on Android)
- [ ] Never store secrets in plaintext storage
- [ ] Sensitive operations (payment, credential change, data export) without biometric gating are flagged

### API key handling:
- [ ] API keys NOT hardcoded in Dart source — use `--dart-define`, `.env` files excluded from VCS, or compile-time configuration
- [ ] Secrets not committed to git — check `.gitignore`
- [ ] Backend proxy used for truly secret keys (client should never hold server secrets)

### Input validation:
- [ ] All user input validated before sending to API
- [ ] Form validation uses proper validation patterns
- [ ] No raw SQL or string interpolation of user input
- [ ] Deep link URLs validated and sanitized before navigation

### Network security:
- [ ] HTTPS enforced for all API calls
- [ ] Financial or health apps talking to a first-party backend without certificate pinning are flagged
- [ ] Authentication tokens refreshed and expired properly
- [ ] No sensitive data logged or printed

---

## 12. Error Handling

### Framework error handling:
- [ ] `FlutterError.onError` overridden to capture framework errors (build, layout, paint)
- [ ] `PlatformDispatcher.instance.onError` set for async errors not caught by Flutter
- [ ] `ErrorWidget.builder` customized for release mode (user-friendly instead of red screen)
- [ ] Global error capture wrapper around `runApp` (e.g., `runZonedGuarded`, Sentry/Crashlytics wrapper)

### Error reporting:
- [ ] Error reporting service integrated (Firebase Crashlytics, Sentry, or equivalent)
- [ ] Non-fatal errors reported with stack traces
- [ ] State management error observer wired to error reporting (e.g., BlocObserver, ProviderObserver, or equivalent for your solution)
- [ ] User-identifiable info (user ID) attached to error reports for debugging

### Graceful degradation:
- [ ] API errors result in user-friendly error UI, not crashes
- [ ] Retry mechanisms for transient network failures
- [ ] Offline state handled gracefully
- [ ] Error states in state management carry error info for display
- [ ] Raw exceptions (network, parsing) are mapped to user-friendly, localized messages before reaching the UI — never show raw exception strings to users

---

## Sources

- [Effective Dart: Style](https://dart.dev/effective-dart/style)
- [Effective Dart: Usage](https://dart.dev/effective-dart/usage)
- [Effective Dart: Design](https://dart.dev/effective-dart/design)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter Testing Overview](https://docs.flutter.dev/testing/overview)
- [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)
- [Flutter Internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
- [Flutter Navigation and Routing](https://docs.flutter.dev/ui/navigation)
- [Flutter Error Handling](https://docs.flutter.dev/testing/errors)
- [Flutter State Management Options](https://docs.flutter.dev/data-and-backend/state-mgmt/options)

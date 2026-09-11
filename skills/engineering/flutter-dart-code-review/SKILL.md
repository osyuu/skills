---
name: flutter-dart-code-review
description: Flutter/Dart review checklist that walks what a general review passes by (accessibility, localization, widget idioms, performance, tests, dependencies) and reports its coverage. Use when reviewing Flutter code. 也認 審查 Flutter / 檢查 Flutter 程式碼 / Flutter コードレビュー. Skip Dart with no Flutter surface, and writing new code.
---

# Flutter/Dart Code Review

A Flutter review has to **walk** the sections where nothing crashes: the tap target nobody can
hit, the string nobody translated, the list that janks on real data, the logic with no test.

Review the target (a diff against its base, a PR, or the files named) the way you normally
would, for crashes, leaks, security and the spec. Then walk every section below that the change
touches. A change touches a section if it adds or edits what the section is about: widget trees
and user-visible text or formatting for Widgets, Accessibility and Localization; lists,
animation and `build()` for Performance; new logic for Tests; `pubspec.yaml` for Dependencies.

Where the project documents its own conventions (CLAUDE.md, AGENTS.md, `analysis_options.yaml`,
a style guide), they win over this list.

## Widgets

- [ ] No `UniqueKey()` created in `build()`: it recreates the element and its state on every
      rebuild. Lists that reorder use `ValueKey` or `ObjectKey`
- [ ] Colors and text styles come from the theme (`colorScheme`, `textTheme`), not literals, so
      dark mode and the design system hold

## Accessibility

- [ ] Tap targets are at least 48×48. A `GestureDetector` around a small `Icon` is the usual
      offender; `IconButton` gives the size; pass it a `tooltip`
- [ ] Color is never the only signal of state: a status dot also carries text, an icon or a
      semantics label
- [ ] Icon-only controls and meaningful images have a semantics label; decorative ones are
      excluded

## Localization

Check only if the project has localization set up (an ARB directory, `l10n.yaml`, or a
localization package).

- [ ] Every user-visible string goes through it, including snack bars, dialogs and app bar titles
- [ ] No string concatenation to build a sentence; use a placeholder message
- [ ] Dates, numbers and currency are formatted for the user's locale, not a fixed pattern or a
      hardcoded `$`

## Performance

- [ ] `build()` does no sorting, filtering, parsing or regex compilation over collections that
      grow; compute it where the state changes
- [ ] Long or unbounded lists use `ListView.builder` or `GridView.builder`
- [ ] Animation goes through the animation framework (`AnimatedOpacity`, `FadeTransition`, an
      `AnimationController`), not a `Timer` calling `setState` on the whole page
- [ ] `MediaQuery.sizeOf(context)` and friends, not `MediaQuery.of(context).size`, so the widget
      doesn't rebuild on every inset change

## Tests

- [ ] New state logic, repositories and non-trivial widgets come with tests in the same change.
      Name each new unit that has none
- [ ] The state transitions the change introduces (loading to data, loading to error, retry) are
      each exercised

## Dependencies

- [ ] `dependency_overrides` in `pubspec.yaml` carries a comment saying why and when it goes

## Report

Severity:

- **Blocker**: a crash, a leak, data loss, a security exposure, or a requirement the change was
  meant to deliver and doesn't.
- **Should fix**: a defect users can see or be shut out by: an accessibility failure,
  untranslated text, jank on realistic data, new logic with no test.
- **Nit**: an idiom or hygiene issue with no effect users can see today.

<review-template>

## Findings

- **{severity}** · `{file}:{line}` · {what is wrong, and what it causes}

## Also noticed

{Observations you're not confident in, or that sit outside the change. Leave it out if there are none.}

## Coverage

- Walked: {the sections above that the change touches}
- Not walked: {the sections it doesn't touch}
- Spec: {checked against where the requirements came from | no spec found, not checked}

</review-template>

"Nothing found" is a valid finding list. The Coverage section is never empty: it is how the
reader tells a clean review from a short one.

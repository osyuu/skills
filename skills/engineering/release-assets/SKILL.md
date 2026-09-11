---
name: release-assets
description: Ships an app release's user-facing, non-code deliverables (release notes, store screenshots, changelog, store metadata). Use when preparing an app release or store submission, writing release notes or what's-new text, re-shooting store screenshots, or editing fastlane metadata or screenshot config. 也認 發版 / 上架 / 寫更新說明 / 截圖要重拍 / リリース準備. Not for library or backend releases with no store listing, a bare version bump, or PR descriptions.
---

# Release Assets

Code has a compiler, tests and review behind it. Release notes and store screenshots have none:
a mistake in them goes straight to users.

## 1. Inventory, confirm, then touch

Before editing the first file, list the complete delivery: every file, every language, every
device size and every variant (for example free and paid), with a done criterion for each.
Languages often differ between deliverables: the app may ship in eight while the store text
covers six. Say so when they do.

Present the list together with the decisions that belong to the user, and wait for an answer
before you touch a file. These are the user's:

- the order of anything users see in sequence;
- markers such as a NEW badge: which items get one, and which lose theirs;
- any copy users will read, including screenshot captions and each release-note line: show
  your draft of it;
- whether existing assets get redone to match the new ones.

Doing the work first and asking afterwards turns every answer the user gives into rework.

## 2. Know why an existing asset looks the way it does

Before you rename, delete or migrate an existing asset, find where its shape came from. Start
with `git log` on it. Assets are usually generated, and output directories are often gitignored,
so if the history isn't here, follow the tool, script or config that produced it, even into
another repository. An element you can't explain is an open question, not noise: put it to the
user before you change it. A word in a filename may be what the generator keys on. The tool
itself may have changed engines while its config stayed on the old schema, so confirm it still
runs before you rely on it.

## 3. Write as the reader, not the author

Release notes answer "what do I get?". The changelog answers "what happened?", and technical
detail belongs there. Before you show the user any release-note or store text, read it as a
stranger to the product:

- **Would it scare them?** Describing a defect they never noticed advertises a bug.
- **Does it knock the previous version?** Users don't need to hear that the old design was bad.
  State the new state.
- **Is there a word only the team uses?** Pipeline, state, rebuild and per-frame are the team's
  words, not the user's.

Several internal fixes become one line that users can feel.

```
Bad:  Fixed a bug where a failed import could corrupt the project you had open.
Bad:  Export is no longer buried three menus deep.
Good: More reliable importing.
Good: Export is now on the share sheet.
```

The first Bad line tells users their data was at risk. The second tells them the old app was
badly designed. Neither tells them what they get.

## Done when

- every item on the confirmed inventory is checked against its criterion, and visual assets were
  opened and looked at, not judged by filename;
- anything changed only for the capture (status bar overrides, demo data, extra simulators) is
  back as it was;
- the report says what was left undone and why.

# Skeletons

These are standalone skeletons, not forms to fill in. Pick parts by the failure you predicted in SKILL.md step 2, not because a skeleton has a section for them. The table at the end lists each part on its own. Every skeleton depends only on what [STANDALONE.md](STANDALONE.md) allows. Most close with what they **bind** and what they **leave**.

Placeholders: `{name}` for short fields, and a sentence of intent for whole passages.

## 1. Vocabulary or rules reference (model-invoked)

```markdown
---
name: {skill-name}
description: {leading-word phrase}. Use when {branch A}, {branch B}, or {a word the user says}.
---

# {Title}

{One or two sentences: what it is. Introduce the **{leading word}** in bold.}

When invoked on its own, apply these {terms / rules} to {the named target} and report
{findings, each with the rule and the cited line}. Stop when every rule has been
applied. "Nothing found" is a valid report.

## Glossary

Use these terms exactly: don't substitute {banned synonyms}. Consistent language is the whole point. Where this repo already names the same thing, use its word.

**{Term}**: {what it is, one or two sentences}. _Avoid_: {synonyms}.

## Principles

- **{Principle}.** {One-sentence reason.}
- **The {name} test.** {A judgement test the model can run on its own.}

## Rejected framings

- **{Rejected frame}**: {why not}. {What to use instead.}
```

**Binds:** the terms, the banned synonyms, and the stopping rule with its report shape. **Leaves:** how the principles apply and how a test result is read. Add an Anti-patterns section only under the conditions in [LEVERS.md](LEVERS.md).

## 2. Gated discipline (model-invoked)

```markdown
---
name: {skill-name}
description: {what it is}. Use when {branch A}, or {branch B}. Don't invoke this for {non-trigger}.
---

# {Title}

{One sentence introducing the leading word in bold.} Skip phases only when explicitly justified.

Use the repo's own vocabulary (README, CLAUDE.md, code identifiers). Where it keeps a
glossary or decision records, respect them.

## Phase 1: {the load-bearing step}

**This is the skill.** {Why this step decides the outcome, in one sentence.}

Ways to {achieve it}, in roughly this order:

1. {first choice}
2. {second choice}
3. {last resort}. Before using it, check that nothing above works.

Phase 1 is done when {an observable state, written as what must be true, with a demand}.

If you catch yourself {the default failure} before this exists, stop: that is the failure this skill prevents.

### When you genuinely cannot {achieve it}

Stop and say so. List what you tried. Ask the user for {what would let you continue}. No {Phase 1 product}, no Phase 2.

## Phase 2: {name}

Generate {3 to 5 candidates} before {the next action}: a single candidate anchors on the first plausible idea.
Each must be {falsifiable / structurally different}. If you can't {state its prediction}, discard or sharpen it.

Show {the candidates} to the user before {acting}. Don't block: if the user is away, proceed on your ranking.

Don't enter Phase 3 until {entry condition}.

## Cleanup

Required before declaring done:

- {a mechanically checkable cleanup, e.g. a grep for the temporary tag comes back empty}
- {the final hypothesis recorded where the repo records decisions; if it records none, propose a place once and ask}
```

**Binds:** the entry condition of every phase; Phase 1's completion criterion and how to stop when it can't be met; the default failure named once, at its gate; the number of candidates and their falsifiability; when the user sees them; the cleanup. **Leaves:** which approach reaches Phase 1, what the candidates are, and their order.

"Proceed on your ranking if the user is away" holds only because ranking is reversible and stays in the workspace. If the next step writes outside the session, stop there instead.

## 3. Branch-first

```markdown
---
name: {skill-name}
description: {what it is}. Use when {branch A situation}, or {branch B situation}.
---

# {Title}

{One-sentence definition with the leading word in bold. {The word} decides the branch.}

## Pick a branch

- **"{the question branch A answers}"** → [{A}.md]({A}.md). {What it produces.}
- **"{the question branch B answers}"** → [{B}.md]({B}.md). {What it produces.}

{The cost of picking wrong, in one sentence.} If it is genuinely ambiguous and the user
isn't reachable, default to {branch} and state the assumption at the top of the output.

## Rules that apply to both

1. **{Rule}.** {Reason.}
```

Each branch file opens with "When this is the right shape": three or four things a user would say, the last one pointing to the other branch.

**Binds:** the branch test, the default, and the shared rules. **Leaves:** how each branch does its work. If one branch needs a gate, put skeleton 2's Phase 1 block in that branch's file. If both need it, put it here, before the shared rules.

## 4. User-invoked orchestrator with an output template

```markdown
---
name: {skill-name}
description: {one line for a person: what it does, what it produces, how it differs from nearby skills}.
disable-model-invocation: true
argument-hint: "{what the user can pass, or nothing}"
---

{Opening: a definition or a job statement, e.g. "Synthesize what you already know; don't interview the user."}

If the user passed arguments, treat them as {what}.

## Process

### 1. Establish {the precondition}

<!-- writer: paste STANDALONE.md part 6 here, with part 2 for the lookup -->

### 2. Gather

Work from what is already in the conversation. If the user passed a reference, fetch it
and read its full body and comments. If you can't fetch it, ask the user to paste it.

### 3. Explore

Read whatever exists; don't assume. {What to look at, as guiding questions:}

- {question}
- {question}

### 4. Draft

{Drafting rules, bound where the baseline failed. If the default leans one way, the
rules must be able to pull back.}

### 5. Confirm

Present {a summary of the draft, not the draft}. Lead with the recommended answer so the
user can accept in a word, and skip what exploration already settled. Ask:

- "{a question aimed at the known failure direction}"
- "{a question}"

Iterate until the user approves.

### 6. Write

Write it with the template below to {destination} <!-- writer: paste STANDALONE.md part 5 -->, and report the path.

<{output}-template>

## {Section}

{One sentence of intent: what goes here, from whose point of view, how long.}

## Out of scope

{What the user explicitly declined.}

</{output}-template>

In every form, {a constraint that applies to all forms}: {reason}. Exception: {when it may be broken}.
```

**Binds:** the precondition step; reading the full evidence; the confirmation point and its questions; nothing written out before approval; the product's sections and *Out of scope*; saying where the product went. **Leaves:** the exploration path, the draft, and the content of every section.

Each step can end on its own "Done when". If the product is small and written in one go, drop `## Process` and keep a few constraints.

## 5. Format file `{X}-FORMAT.md`

````markdown
# {X} Format

{X} lives where the repo already keeps them. If there is no such place, propose `{path}/` once
and ask. Number them sequentially: `0001-slug.md`. Create the directory only when the first {X} is written.

## Template

```md
# {Short title}

{1 to 3 sentences: what and why. Avoid {the common empty phrasing}; push for {the concrete thing}.}
```

That's it. {X} can be a single paragraph. The value is in recording _that_ {...}, not in filling out sections.

## Optional sections

Only include these when they add genuine value. Most {X} won't need them.

- **{Field}**: only when {condition}

## Rules

- **{Rule}.** {Reason.}
- **{X} is {what it is} and nothing else.** {What it does not hold.}

## When to write one

All three must be true:

1. **{Criterion}**: {explanation}
2. **{Criterion}**: {explanation}
3. **{Criterion}**: {explanation}

### What qualifies

- **{Kind}.** "{a real example}"

### What does _not_ qualify

- {Kind}. {Why not.}

## Supersession

When a later {X} contradicts an earlier one, mark the old one `Status: superseded by {X}-NNNN` rather than deleting it.
````

The step in SKILL.md that uses it says: `Use the format in [{X}-FORMAT.md](./{X}-FORMAT.md).` A real format file takes only the sections it needs. When the number is an id that the user will type into a command, pick the width that is easiest to type.

## 6. Sub-agent brief

```markdown
{One sentence of background: which part of the whole this agent owns.}

**Desired outcome:** {the behaviour or answer wanted, not how to get it}.

**Technical brief:** {file paths, coupling details, what sits behind the interface. Written separately from what the user was told.}

**Reference (pasted in full: you have no other access to it):**
{the part of the skill it needs, pasted from the single source at dispatch time}

**Vocabulary:** {this skill's terms, plus the repo's own terms}.

**Constraint for this agent:** {a constraint only this agent gets, to force divergence}.

**Acceptance:** {a checkable condition that can fail}.

**Out of scope:** {what not to touch}.

Cite the source for every claim.
Do not invoke {this skill} or spawn more agents: do this directly.
Report in under {N} words.
```

**Binds:** the outcome, acceptance, scope, sources, the recursion ban, and the length. **Leaves:** implementation and exploration. A brief that waits days before an agent picks it up does the opposite: it names no paths or line numbers, only interfaces and behaviour, because the code will have moved.

## 7. Stateful workspace

```markdown
---
name: {skill-name}
description: {one line for a person}, within this workspace.
disable-model-invocation: true
argument-hint: "{what to do this time, or nothing}"
---

{Job statement. This is a stateful request: {it spans several sessions}.}

If the user did not say where to keep the work, look for an existing `{main}.md` in the repo first. If there is none, ask, and tell the user to pass the path, or keep the workspace at that spot, next time.

## Workspace

The state lives in this directory:

- `{main}.md`: {what it is for}. Use the format in [{X}-FORMAT.md](./{X}-FORMAT.md).
- `./{products}/*.md`: {one file per product, how they are numbered}.
- `NOTES.md`: the user's standing preferences and your working notes.

Create files lazily: only when you have something to write.

## Each session

1. Read the workspace first. The folder is the continuity, not the conversation.
2. {One step at a time.} Re-read the file from disk before every write, and keep the user's edits.
3. {Write at the moment something is settled, not in a summary at the end.}
```

**Binds:** state lives only in the directory; the file list comes first, with one format file per product; the workspace is found before anyone is asked; files are re-read before writing; files are created lazily. **Leaves:** what each session does, and the content.

**Periodic variant.** A check that is rerun every so often needs no workspace, only a cross-run record kept where the repo keeps decisions (STANDALONE.md part 4):

- **Declined items**: when the user declines something for a reason that will still hold next time, record it. Read the record first, match by concept, and don't raise the item again unless the evidence has changed. Give each entry a greppable prefix such as `Declined:`.
- **Base point**: the report names the commit it looked at, so the next run knows what changed.
- **Coverage**: surveyed, not surveyed, and left alone with a reason, so the next run starts where this one didn't look.

## 8. Alias

A user-invoked frontmatter whose whole body is `Call the Skill tool with "{primitive}".` (for two, `Call the Skill tool twice, for "{a}" and "{b}".`). The primitive must ship alongside and be model-invoked. A one-line hand-off doesn't guarantee the callee loads in full, so for a load-bearing behaviour, inlining its core is more reliable than an alias.

## Parts table

| Part | Skeleton | Take it when |
|---|---|---|
| Opening: definition plus leading word | 1, 2, 3 | A word the model already knows can carry the skill |
| Opening: job statement plus one thing not done | 4 | The default adds a step (e.g. interviewing the user again) |
| Precondition step | 4, step 1 | Without the fact the output is wrong |
| Soft-read line | 2 | The file sharpens the output, and the skill runs without it |
| Reference with its own stopping rule | 1 | The skill is rules or vocabulary and may be told "go" |
| Gate: "This is the skill", criterion, stop when it can't be met | 2, Phase 1 | The default skips this step |
| The default failure named once, at its gate | 2, Phase 1 | You know how it cuts the corner |
| Branch test plus "When this is the right shape" | 3 | The paths produce different things |
| Candidates, falsifiable, shown to the user, default when away | 2, Phase 2 | The default anchors on the first idea |
| Verbatim questions plus iterate until approved | 4, step 5 | The user decides here, and the default has a known lean |
| Output template, outer constraint, exception | 4, step 6 | Someone downstream reads the product |
| Evidence fields, label conditions, *Also noticed* / *Left alone* | 4's template, extended per LEVERS.md | The product must be checkable and the candidate list short |
| Format file | 5 | A secondary product has its own rules and its own "when to write" |
| Mechanical cleanup list | 2, Cleanup | Something temporary has to go |
| Sub-agent brief | 6 | The skill dispatches agents |
| Workspace plus re-read before writing | 7 | The work spans sessions |
| Cross-run record | 7, periodic | The same check reruns over time |

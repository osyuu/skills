# Standalone parts

A product is **standalone** when a teammate who has never heard of Matt, on a machine without his plugin, gets its full behaviour. The rules below say what a product may lean on. The seven parts replace the places where a Matt-style skill would lean on another skill, a setup step or a workflow file. Each part is text you can copy: adapt the wording and keep the shape. Why a product can't simply call Matt's skills or rely on his setup is in [MATT-ARCHITECTURE.md](MATT-ARCHITECTURE.md).

## Rules for every product

- **Self-contained.** A product may call only skills that ship in the same place from the same author, as `Call the Skill tool with "<name>"`, and only when that skill is model-invoked. The model cannot reach a user-invoked skill at all, so a user-invoked sibling can only be named for the user to run ("tell the user to run `/<name>`"). Expect the agent to say that skill isn't installed: user-invoked skills are hidden from its list. Write the name the way the reader's skill list shows it: a skill shipped in a plugin appears as `<plugin>:<name>`.
- **Soft-read, never require.** Files that another workflow leaves in a repo (a domain glossary, decision records, per-repo agent config, a local issue directory) are read when present and useful. They are never required, never reported as missing, and the product never suggests creating them.
- **General concepts, not flow names.** Words like seam, tracer bullet and deep module are fine: the model already knows them. File names, skill names and setup steps that belong to one author's workflow are not, because the reader can't resolve them.
- **No facts about any repo's current state.** The product checks at run time, and the result picks the branch. A path, branch name or count written into the product goes stale without anything to signal it.
- **Harness-neutral only if it ships across harnesses.** A product for one harness may use that harness's tools. One meant for several leaves out harness tool names.

## 1. Interview in rounds

Replaces calling an interviewing skill.

```markdown
Interview the user in rounds until you reach a shared understanding. Each round, ask
every question whose prerequisites are already settled: number them and give your
recommended answer to each. A question whose answer depends on another question still
open this round waits for a later round.

Look up facts yourself (files, config, history, tools) and never ask the user for
anything you could find. Don't block on a lookup: ask the questions that don't depend
on it now. Decisions are the user's: put each one to them and wait.

Done when no branch is left unasked, nothing is silently assumed, and the user confirms
the shared understanding.
```

Round format:

```
**Q1: <title>**: <question, with the choices if there are any>
Recommended: <your answer>

**Q2: <title>**: ...
Recommended: ...
```

The recommendation lets the user accept an answer in one word. Numbered questions let the user answer the whole round by number.

## 2. Project facts from the environment

Replaces reading a per-repo agent config file.

```markdown
Find <the fact> in this order: CLAUDE.md or AGENTS.md; the README; config files
(package.json scripts, pyproject.toml, Makefile, CI config, the directory layout).
If none of them settles it, ask the user once and use the answer for the rest of the
session. If there is no answer, use <default> and say so.
```

Name the kind of fact ("the project's automated checks"), not a command. The command belongs to the repo, and the product runs in every repo.

## 3. Vocabulary source

Replaces requiring a glossary file.

```markdown
Use the words this repo already uses: in its README, CLAUDE.md or AGENTS.md, and code
identifiers. If the repo keeps a glossary, prefer its terms.
Don't coin a domain term the repo doesn't use.
```

## 4. Where decision records go

Replaces a fixed ADR directory.

```markdown
Record the decision where this repo already keeps decisions. If it keeps none, propose
a path once, ask, and say where you wrote it. Create the directory only when the first
record is written.
```

## 5. Default output destination

Replaces publishing to an issue tracker by default.

```markdown
Write the result to a file and report its absolute path. Put it where the repo already
keeps such files. If there is no such place, choose a sensible one and say where. For
a one-off output, use the OS temp directory. Publish anywhere else (a tracker, a PR, a
chat) only when the user asks.
```

## 6. Preconditions obtained inside the skill

Replaces "this should have been provided to you by an earlier skill or setup step".

The product's first step gets what it needs, either by looking it up (part 2) or by asking. Each precondition is owned by a step. A precondition that no step owns never gets met.

```markdown
### 1. Establish <the precondition>
Look for <it> in <where>. If it isn't there, ask the user for it. Done when <it> is
stated in the conversation.
```

## 7. A reference skill's own stopping rule and output

Replaces "consult this while running a driver skill".

A vocabulary or rules skill with no process and no stopping rule makes one up when an agent is told to "go" with it. A standalone product can't count on a driver skill to hold it, so it carries its own:

```markdown
When invoked on its own: apply these <rules / terms> to <the named target>, and report
<a short list of findings, each with the rule it breaks and the line it cites>. Stop
when every rule has been applied to the target. "Nothing found" is a valid report.
Don't redesign beyond what was asked.
```

A skill shipped alongside that invokes this reference still frames the call, for example: "call the Skill tool with "<name>" for the vocabulary; it is a reference to consult, not a session to run."

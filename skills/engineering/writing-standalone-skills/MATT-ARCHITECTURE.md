# Matt's composition architecture (for understanding only)

This file explains how Matt's skills fit together, so you can see what a Matt-style skill leans on and what you have to replace. **Don't copy any of it into a product.** Every mechanism here assumes his plugin and his setup step are on the reader's machine, and a standalone product can't assume that. The replacement for each one is in [STANDALONE.md](STANDALONE.md).

## Primitives and invocation

Matt's set splits on one axis: who can reach a skill.

| | Model-invoked | User-invoked |
|---|---|---|
| Frontmatter | no `disable-model-invocation` | `disable-model-invocation: true` |
| Reached by | the model, the user, other skills | only a user typing `/name` |
| Description | model-facing, with trigger branches | human-facing, one line |
| Cost | always-loaded description | zero context, but the human has to remember it |

A user-invoked skill can call model-invoked ones, never the reverse, and never another user-invoked one. So any reference that several skills share has to be model-invoked. Reference that two user-invoked skills both need goes into a plain file outside the skill system. When the user-invoked skills pile up, a router skill names them for the human, and it can only hint, never fire them.

Some small skills are **primitives** (an interview discipline, a vocabulary, a writing theory). Others are thin wrappers or orchestrators that call them. An alias can be a single line: `Call the Skill tool with "grilling".`

**In a product:** only skills that ship with it can be called. Shared reference lives in a sibling file.

## Setup-generated config

One user-invoked setup skill explores the repo, asks the user, and writes per-repo seed files: which issue tracker to use, which triage label strings, where the domain docs live. It also adds a block to the repo's CLAUDE.md or AGENTS.md pointing at them. "The skills themselves are identical everywhere": they read the seeds at run time. The meaning lives in the consuming skill, and the seed records only how this repo expresses it.

**In a product:** there is no setup step to rely on. Use environment discovery with a default (STANDALONE.md part 2), preconditions obtained in the product's own first step (part 6), and a file as the default output (part 5).

## Hard and soft dependency pointers

- **Hard dependency**: without the config the output is wrong, so the skill carries one explicit line: the config "should have been provided to you. If not, tell the user to run" the setup skill. The line tells the user to run it because setup is user-invoked, and no skill can call it.
- **Soft dependency**: the config only sharpens the output, so it appears in vague prose ("the project's domain glossary", "ADRs in the area you're touching"). If it's missing, the skill still works.
- Reading a glossary for vocabulary is a soft pointer. Actively building the glossary is a separate skill.

**In a product:** a hard pointer to a setup skill becomes a precondition step. A soft pointer becomes a soft-read of whatever the repo already has, never named as a file another workflow creates.

## Skills calling skills

- The operative form is `Call the Skill tool with "<name>"`, because "Naming the tool is what gets it fired". A bare `/name` in prose may never load. A relative path into another skill's folder breaks when that skill moves.
- One skill per call: `Call the Skill tool twice, for "a" and "b".`
- A skill calling a reference skill frames the call ("a reference to consult, not a session to run"), because the reference has no process of its own and makes one up if it is run.
- A sub-agent inherits nothing, so the brief pastes in the reference it needs.
- Constraints travel through products. A spec records agreed seams, and later skills work only at those seams, so the binding runs through the document, not through a call.

**In a product:** the same call form applies to skills that ship alongside. A reference that might be run alone carries its own stopping rule (STANDALONE.md part 7).

## Where the pieces live

Per-repo seeds sit where setup put them. Durable decisions go into the repo, created lazily (a glossary, decision records). Issues go to the configured tracker, or to a local markdown directory when none is configured. One-off outputs go to the OS temp directory. A product can soft-read any of these that it finds. It never creates them because another workflow would have.

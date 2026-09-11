# Theory and pruning (fallback)

Matt's `writing-for-agents` is authoritative; this is a fallback for when it isn't installed. If it is installed, call the Skill tool with "mattpocock-skills:writing-for-agents" and use it instead of this file. The two can drift, and when they disagree the original is right.

Use this file for the pruning pass in SKILL.md step 6. Apply every section to the draft.

## Context pointers

A **context pointer** is a line in the agent's context that names material outside it and says when to reach for it. A skill's description is a pointer, and so is a line in CLAUDE.md that names a doc. What decides when the agent reaches the material, and how reliably, is the pointer's wording, not the material. If the material is needed but the pointer is weakly worded, sharpen the wording first, and inline the material only if sharpening fails.

A pointer says what the material is and lists the **branches** that should trigger it, where a branch is a distinct case the document handles. An always-loaded pointer costs something on every turn, so prune it harder than the body. Put the leading word first, write one trigger per branch (synonyms for one branch are that branch written twice), and cut identity the body already carries.

A pointer only fires when the agent is already thinking of its words. A failure that happens while the agent's attention is elsewhere needs a file, a script, a lint rule or a hook instead (LEVERS.md).

## The two loads

- **Context load**: what always-loaded material costs the agent's window on every turn, whether it fires or not.
- **Cognitive load**: what it costs the human to know which documents exist and when to use each. The human is the index. Spend this load where human judgement matters, and remove it where it doesn't.

Material behind a pointer costs only the pointer's line. Material with no pointer relies entirely on someone remembering it.

## Information hierarchy

A document holds **steps** (ordered actions) and **reference** (definitions, rules and facts, consulted on demand). Each piece sits on a ladder: in-file step, in-file reference, or disclosed reference in another file behind a pointer.

- **Progressive disclosure** moves material down that ladder so the top stays legible. The test is branching: inline what every branch needs, and disclose what only some branches reach. Reference that buries the steps turns attention to them into a coin flip.
- **Co-location**: keep a concept's definition, rules and caveats under one heading. Scattering is not duplication. Duplication writes one meaning twice, scattering splits one meaning across places.
- **Sprawl**: a document too long even when every line is live. The fix is the ladder, not deleting live lines.

## Completion criteria

Every step ends on a **completion criterion**.

- **Clarity**: can the agent tell done from not done? A vague bound ("understanding reached") invites premature completion, because the steps still ahead pull the agent forward. Sharpen the bound first. Split the sequence only if the bound is irreducibly fuzzy and you have actually seen the rush. Splitting helps only across a real context boundary, such as a hand-off or a sub-agent dispatch.
- **Demand**: how much the criterion requires. "Every modified model accounted for" drives legwork, and "produce a change list" doesn't. Demand also binds flat reference: "every rule applied".

The strongest criteria are both checkable and exhaustive. A checklist of a dozen boxes is a dozen demands, so it grows a skill in the "add a bit to everything" direction.

## When to split

- **By sequence**: when the steps after this one tempt the agent to rush it.
- **By invocation**: split off a model-invoked skill only when it has a distinct leading word that should trigger it on its own, or another skill must reach it. The new description is permanent context load, so that reach has to be worth it.

## Leading words

A **leading word** is a compact concept the model already holds, and the agent thinks with it while running the document (_tracer bullet_, _fog of war_, _red_). Repeat the word, never the sentence, and it collects a distributed definition. A coined word works only if you define it, and it brings no priors.

It anchors twice: in the body it anchors execution, and in a pointer it anchors triggering. Look for chances to use one. The same three adjectives at three sites collapse into one word ("fast, deterministic, low-overhead" becomes _tight_). A sentence gesturing at one idea collapses too ("a loop you believe in" becomes _red_), which turns a fuzzy gate into an observable state. A word too weak to beat the default is a no-op. Swap in a stronger word, not a different technique.

## Negation and negative space

- **Negation**: a prohibition puts the forbidden behaviour into context and makes it more available. State the target behaviour positively. Keep a prohibition only as a guardrail you can't phrase positively, and pair it with the positive target.
- **Negative space**: every decision the document leaves unwritten goes to the model's priors. Read the draft for what it doesn't say, and choose each gap: fill it, or leave it deliberately. The default is to leave it (SKILL.md step 5).

## Pruning

- **Single source of truth.** Keep each meaning in one place. Duplication costs maintenance and tokens, and it raises a meaning's weight above its real rank. To raise a rule's weight on purpose, repeat it (LEVERS.md, anti-patterns).
- **The environment is a source too.** Scripts, config files, directory layout and `--help` are all sources, and a document that restates them is a cache. Keep only what the agent can't find by looking: "the unwritten convention, the reason behind a choice, the gotcha no config confesses." Leave one-file, one-command lookups to the environment.
- **Relevance.** Every line must still bear on what the document does. A line fails when it never bears on the task or when the world it describes has changed. Without pruning, stale layers settle, because adding feels safe and removing feels risky.
- **No-ops.** An instruction the model already follows by default costs load and says nothing. The test is behavioural and relative to the model: does removing the sentence change what the agent does? Settle a disagreement by running the document (SKILL.md step 6), not by debating it. When a sentence fails, delete all of it, not a few words.
- **Length is not the target.** An agent told to "streamline" optimises for length, because length is what it can see. The no-op test is about behaviour, not looks.

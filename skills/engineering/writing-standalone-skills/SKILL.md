---
name: writing-standalone-skills
description: Draft a new Claude Code skill in Matt Pocock's style whose product runs standalone, in any repo, for anyone, checked against a baseline run.
disable-model-invocation: true
argument-hint: "What the new skill should do, or nothing to be asked"
---

Write a new skill in Matt Pocock's style and way of thinking. The product is **standalone**: it gives its full behaviour to a teammate who has never heard of Matt, on a machine without his plugin. That teammate is the reader every step below writes for.

If the user passed arguments, treat them as the job the new skill does. Otherwise step 1 asks.

A **baseline** is an agent given the same job with no skill: same model, same task, and none of your setup. A skill binds only where the baseline goes wrong and leaves the rest to the model. Each binding the baseline didn't need costs load and takes judgement away from the model, and buys nothing.

Keep working notes outside the product: the failure each part answers, and what was run or skipped. They feed the final report and never go into the product.

## Process

### 1. Interview

Settle with the user: the job, who invokes it (recommend by the rule in step 3; the user decides), what it produces and for whom, and where the draft goes. If `mattpocock-skills` is installed, call the Skill tool with "mattpocock-skills:grilling" to settle only these four. Otherwise run the interview yourself as in [STANDALONE.md](STANDALONE.md) part 1.

Find out where the repo keeps skills (a `skills/` tree, `.claude/skills/`, a plugin manifest) and follow its conventions for language, frontmatter, punctuation, layout and registration. If it keeps none, propose a path once and ask.

Done when the user has confirmed the job, the invocation, the output and the path, and you answered no question on their behalf.

### 2. Predict the failure, then check it (the gate)

Write one sentence: what an agent does with this job when it has no skill, and which way it goes wrong. Then run a baseline and watch where it actually fails, as in [TESTING.md](TESTING.md). A failure you only predicted is a guess, and a gate built on a guess can land on a step the baseline already does right.

- Where the baseline is right, bind nothing. If it does the whole job right, stop and ask the user whether the skill should exist.
- Two kinds of binding skip this check: a shape that a program or another skill parses, or that a person answers by number; and an irreversible or outward-facing action. One right run doesn't make every run right, and one wrong run of either kind costs too much.
- A small skill whose product is written in one go and is cheap to get wrong needs no fixture. The cold read in step 6 is enough. Mark the failure "inferred, not run".

Done when your notes say where the baseline fails and what the failure looks like, or say "inferred, not run" and why.

The failure sentence is not the skill's opening. It decides what gets bound. If the skill has a leading word, the word names the positive answer to this failure. The failure itself appears in the product at most once: at the gate where it happens, or as the one anti-pattern that restates it.

### 3. Pick invocation and parts

**Invocation.** Recommend model-invoked only when an agent must reach it on its own, or another skill must. Otherwise recommend `disable-model-invocation: true`: it costs no context until someone types its name.

- A model-invoked description says what the skill is, then `Use when` with one trigger per distinct branch. Add a non-trigger if a generic word would make it fire when it shouldn't.
- Model-invoked means the agent can reach it, not that it will at the right moment. An agent mid-task, such as one that just finished its own change, often doesn't think of the skill, and rewording the description rarely fixes that. If the job depends on that moment, test it in step 6. If it doesn't fire, the dependable trigger is a hook, which is a project decision: put it to the user rather than adding it yourself.
- A user-invoked description is one line for a person browsing commands, with no trigger list.
- Quote a description that contains `: `, or the frontmatter fails to parse.
- An `argument-hint` needs one body sentence saying what to do with the argument, and with none.

**Parts.** Start from the skeleton in [SKELETONS.md](SKELETONS.md) that fits. Take only the parts the step 2 failure calls for. Wherever a part would lean on another skill, a tracker, a glossary file or a setup step, use the matching part in [STANDALONE.md](STANDALONE.md) instead.

**Steps or constraints.** A large product built over several rounds gets numbered steps, and so does a job whose later steps tempt the model to rush the current one. A small product written in one go gets a few constraints and no steps.

Done when the frontmatter is written and your notes name, for every chosen part, the failure it answers.

### 4. Bind where the baseline failed, on evidence

Write the body in the surface form of [STYLE.md](STYLE.md). Then, only where the failure calls for it:

- **If a word the model already holds can carry the behaviour, use one leading word.** Among candidates, take the one that turns a fuzzy gate into an observable state.
- **Put the gate on the step where the baseline failed.** End it on a checkable state with a demand ("every X accounted for"). Say what must be true, not how to get there.
- **Bind the output, not the thinking.** A gate's evidence needs a field in the product. If the product grades things, each label needs an operational definition. If it is a list of findings, overflow needs a home. Rules that prescribe an order of reasoning, override the repo's documented decisions, or name the fix in a heading pull the reasoning away from the repo. Details: "Bind evidence, not thinking" in [LEVERS.md](LEVERS.md).
- **If a reader parses the product or compares it across runs, give it a template**: [TEMPLATES.md](TEMPLATES.md).
- **Write examples for the class of task**, not for the run you just watched. Keep that run as evidence and strip what belonged to its repo and files.

Done when your notes name, for every bound thing, the failure it prevents, either seen in the baseline or marked "inferred, not run".

### 5. Read the negative space

Every decision the skill leaves unwritten goes to the model's priors, and that is the default. Read the draft for what it leaves unwritten. For each failure the baseline showed that the draft doesn't answer yet, look up the matching row in [LEVERS.md](LEVERS.md) by the failure, not by the lever, and add that lever. Don't walk the index looking for gaps.

Done when every observed failure has a bound, and nothing was added on this pass without one.

### 6. Run it against the baseline, then prune

Run the draft and the baseline on the same fixture ([TESTING.md](TESTING.md)). Their behaviour should differ only where you bound.

- Bound, and no difference: a no-op. Cut it, or replace it with a stronger word.
- Bound, and worse than the baseline's own approach: replace the step with the baseline's approach, or cut it.
- Not bound, yet different: find the sentence that does it.

The test unit is one bound thing against one fixture case. Don't try to test each sentence. A no-op you only judged by reading is a guess, so say so.

Then prune. If `mattpocock-skills` is installed, call the Skill tool with "mattpocock-skills:writing-for-agents" and apply it to the draft. Otherwise use [THEORY.md](THEORY.md). Move material into a sibling file only if just some branches need it and it is big enough to be worth the extra hop.

Then get a cold read: a fresh context (a new session or a sub-agent) reads the draft as the agent would. A context that reviews its own draft only confirms it.

Fixes from the comparison and the cold read are new text that nobody has reviewed. Prefer replacing or deleting to adding. Don't rerun until it comes back clean: every fix creates new surface, so the loop never converges.

Done when the comparison ran once or you have said it didn't, every no-op is cut or flagged, and each cold-read finding has an outcome: applied, or declined with a reason.

### 7. Prove it stands alone

Judge every reference in the product to another skill or to a file. Each must be one of these:

- **shipped alongside**: a sibling file, or a model-invoked skill that ships in the same place from the same author, called as `Call the Skill tool with "<name>"`;
- **named for the user**: a user-invoked sibling that ships alongside, written as "tell the user to run `/<name>`";
- **discovered from the environment**, with a default for when the fact isn't there;
- **soft-read**: read if present and useful, never required, never a prompt to create it.

The rules behind these are in [STANDALONE.md](STANDALONE.md).

Then do a clean run with the command in [TESTING.md](TESTING.md), with the product installed the way its reader will get it. First confirm, with a no-tools probe, that the session sees only the project's instructions and skills. If the product depends on something from your own machine without saying so, the clean run is where that shows up.

Done when every reference is one of the four kinds, and the clean run reached the product's first user decision or finished, or you have said it wasn't run.

## Done when

Steps 1 to 7 are each done, and in the product itself:

- every step ends on a completion criterion;
- the product bounds a free space only where a baseline run showed a failure, where you marked the failure "inferred, not run", or for one of the two exempt kinds in step 2. Each bound targets its failure (the bound-type table in [LEVERS.md](LEVERS.md)).

Report the product's path, what is bound and against which failure, what is "inferred, not run", and which runs (baseline, comparison, cold read, clean run) you skipped.

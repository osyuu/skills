# Lever index

This file covers the mechanism: what makes a skill bind, and what leaves the model free. How a skill reads on the page is in [STYLE.md](STYLE.md).

The aim is that "the agent takes the same _process_ every run rather than producing the same output" (Matt, `writing-for-agents`). Bind the shape of the result, the gates, the vocabulary, the irreversible actions and the scope. Leave the path, the content and the judgement to the model. Forcing compliance harder buys little and costs the model's judgement.

## Bind when any of these holds

1. **Something parses the shape.** A program, a tracker operation or another skill reads it, or a person answers it by number.
2. **A mistake is irreversible or goes outward.** Examples: closing an issue, pushing, writing into someone else's system.
3. **This step is the skill's whole value.**
4. **The model's default habit is the failure itself**, as seen in the baseline.
5. **Wording has already failed, or the failure happens while the agent is thinking about something else.** Move the bind into a file, a script, a lint rule or a hook. More words will not reach an agent whose attention is elsewhere.

Items 1 and 2 hold even when the baseline got it right.

## Leave when any of these holds

1. The content depends on the situation, so a fixed rule breaks every other situation.
2. The model's prior is already good enough, and writing it down only restates it (a no-op).
3. Variety is the value.

## Bind evidence, not thinking

| Do | Because |
|---|---|
| Ask for an output field that holds something checkable (a trace, a commit, a cited line) | It forces real exploration without prescribing steps. It also decides what gets looked for, so give overflow a home to catch the rest |
| Give every gate's evidence a place in the product | A check with no field happens in the trace, and the user never sees it |
| Write the qualifying condition for every grade label | A label with only a name ends up on anything |
| Give overflow a home: *Also noticed*, *Left alone* with a reason | Side findings get twisted into candidates or dropped, and coverage is invisible |
| Put presentation after truth, keep definitions consistent inside one skill, name candidates by the problem rather than the fix | Length caps squeeze out uncertainty, two definitions of one field force the runner to pick one, and a heading that names the fix anchors the answer before the user chooses |
| Write hard boundaries (read-only, where to stop) and how to check them | An unstated boundary gets crossed, for example by a sub-agent that runs tests in a read-only task |
| Lock vocabulary only for words that describe code shape. Domain terms and structures the repo has already named keep the repo's words | A borrowed principle overrides a decision the repo documented, and the runner spends effort renaming |

## When a free space has failed, fit the bound to the failure

| Missing bound | What goes wrong without it |
|---|---|
| Stopping rule | Research runs too deep, or too wide and misses the detail that mattered. A reference skill told "go" invents a process |
| Entry condition | The skill runs on a case it should decline, e.g. a test loop on a change with nothing independent to assert |
| Reverse definition ("X is Y and nothing else") | The product grows into something it isn't, e.g. a glossary that becomes a spec |
| Evidence source | A cheaper query stands in for the full read and leaves out the field that mattered |
| Framing defence (graded strength) | A skill built to output findings never says "nothing worth doing here" |
| Recursion ban | Sub-agents invoke the same skill and multiply |
| Scope and coverage record | Exploration never stops, and nobody can tell what was covered |

**Exploring skills stop by:** declaring scope before scanning, capping the number of candidates, keeping a coverage record (looked at, not looked at, left alone with a reason), and treating "every declared area walked" as the completion criterion. "Nothing found" is a valid result.

Not every gap needs "stop and ask". Stop only where the next step writes outside the session or makes a decision that belongs to the user. Facts are the agent's to find, and preparation happens before the question.

## User absent: continue or stop

- **Continue on a default and state the assumption** when the next step is reversible, stays in the workspace, and decides nothing for the user.
- **Stop** when the next step writes outside the session (a tracker, a remote, someone else's files) or settles a decision that belongs to the user.
- **Push right either way.** Finish all the preparation first, so a stop leaves a summary the user can decide from.
- When nobody is there at all (automation, or another skill invoked it), treat the user as absent, and describe the stopped state as a defined delivery state.
- What counts as the user's decision is itself a design choice. State it in the product.

## Keep exceptions out of the constrained party's reach

An override written in a file the agent itself writes becomes a permission it grants itself. Put exceptions where only the user or the skill author writes.

## Rule conflicts inside one skill

When two rules pull against each other, they yield in this order: hard boundaries set by the environment or the user; the user's instructions in this invocation and the repo's documented rules; truth (evidence fields, no invention); the skill's own vocabulary and principles; presentation. Use this order to resolve conflicts while drafting. Write an override rule into the product only when it really has two rule sources. Two definitions of one thing inside one skill are not a conflict, they are a bug: keep one source.

## Push both ways

When the comparison shows a directional rule overshooting, pair it with a check that pulls back, rather than adding a second push. Example: slicing rules push toward smaller tickets, and a scripted question, "Does the granularity feel right? (too coarse / too fine)", pulls back.

## Prohibitions and anti-patterns

- State the target positively in the steps. Use a prohibition only as a guardrail at a gate or an irreversible action, and pair it with the positive target.
- An anti-pattern entry is a recognizer: a bold name, a reason, and a tell (what you'd see) or the positive goal.
- Restating a rule as an anti-pattern raises its weight. Do it only for the skill's main failure, the one predicted in step 2. Elsewhere, fold the tell into the rule.

## The index

Look up a row by the failure you observed, then add its lever. Don't walk the index looking for gaps: every row you read as a menu is an invitation to bind without evidence.

| Failure observed | Lever |
|---|---|
| The agent skips the hard step and does the easy part | Gate on the load-bearing step, plus stop-and-report when the step can't be done |
| Premature or shallow completion | Completion criterion as a required state, with a demand |
| A check the skill created passes on everything | Watch the check fail once |
| The error surfaces where it is expensive | Fail at the cheapest point |
| A cheap query leaves out the decisive field | Read the full evidence (body and comments, not a summary query) |
| Judgement applied mid-work instead of at the boundary | Order the questions, leave the answers free |
| Downstream readers get a different shape each run | Output template: fixed frame plus free sections |
| A periodic skill re-raises the same thing | Cross-run record: declined items, base commit, coverage |
| A template filled with boilerplate, or every optional field padded | Placeholders that state intent, and a declared minimum form |
| Synonyms drift, or one word takes two meanings | Locked vocabulary (code-shape words only) |
| The product grows into something it shouldn't be | Reverse definition |
| Wrong tone, and walls of ids a person can't read | Product prose style (sample phrasings, names for people, ids for commands) |
| The agent decides on the fly whether to wait | Classification that lets behaviour fall out (each item labelled "needs a human" or "agent can do") |
| One axis masks the other | Separate axes, not merged or reranked |
| Findings can't be checked | A cited source on every finding |
| Wording already failed, or the agent isn't thinking of the word when it fails | A file, script, lint rule or hook instead of wording |
| Temporary things survive | Mechanically cleanable markers (a unique tag on temporary logs) |
| A write-out that can't be taken back | Stop before irreversible actions |
| Others read AI output as a person's | Mark AI-generated output that goes to others |
| Credentials end up in the output | Redact secrets first |
| The user's edits are lost | Merge into the user's files, never overwrite, and say what was added |
| Steps or behaviour that don't exist | Don't invent: say what you don't know, then check or ask |
| Gold-plating, drift into adjacent features | Scope boundary, and the skill's own *Out of scope* |
| Work that doesn't fit a session | Unit of work sized to one context window |
| The next step doesn't know what was agreed | Constraints that travel through the product to the next reader |
| The precondition is never met | A step that owns every precondition |
| Sub-agents lack context and self-expand | Sub-agent brief that carries its references, bans recursion and demands sources |
| Steps restate a loop the model already runs | A leading word instead of restated steps |
| A rigid list misses the situation | Guiding questions instead of a checklist |
| The heaviest approach used first | Preference order, with a self-check before the last resort |
| Quantity runs away, or comes out too small | A default with a cap |
| The full procedure on a case that doesn't need it | Early exit when the skill isn't needed |
| A rule applied literally | A self-check or judgement test the model can run |
| The work anchors on the first idea | Forced divergence (several candidates, different constraints) |
| A rule forced onto cases it doesn't fit | Rule plus reason plus exception |
| Stuck on ambiguity, or a side silently picked | Default, and state the assumption |
| The user is asked too much, or asked what is already settled | Recommended answer first, settled questions skipped |
| The agent decides for the user, or hands the user fact-finding | Facts to the agent, decisions to the user |
| The user is interrupted early and given raw output | Push right: brief the user, don't hand over a draft |
| The question misses the known failure | The question written verbatim where the user must answer |
| End-of-session summaries drift, user edits get overwritten, answered questions are asked again | Write at the moment, re-read before writing, resume from the product |
| Content invented from memory | Primary sources, not model memory |
| No visible basis for a conclusion, labels used as adjectives, overflow bent into candidates | See "Bind evidence, not thinking" above |

A few free-side moves have no row because you use them while writing a step: naming behaviours as moves rather than steps, choosing from a menu with a criterion, narrowing scope before exploring, tracing decisions back to a stated purpose, matching by concept rather than keyword, treating "nothing found" as a result, deliberate vagueness where the agent should judge the extent, and steering with natural language rather than flags or modes.

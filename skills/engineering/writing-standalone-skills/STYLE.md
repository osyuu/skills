# Style

This file is surface form only. Remove any feature listed here and the skill still behaves the same; it just stops reading like Matt. What a feature does is in [LEVERS.md](LEVERS.md) or [THEORY.md](THEORY.md). When a style rule and a binding disagree, the binding wins. The target repo's own language and punctuation conventions outrank this file.

## Length

Short. Length follows gates and templates, not category. For scale, counting frontmatter:

| Shape | Lines |
|---|---|
| One-line hand-off to a skill shipped alongside | about 7 |
| Pure numbered steps, no opening | about 15 |
| An output with no steps, a few constraints | about 16 |
| Branch-first entry, branches in sibling files | about 26 |
| A discipline carried by a leading word the model already runs | 30 to 40 |
| Orchestrator with an embedded template | 105 to 130 |
| Gated discipline, vocabulary reference, stateful workspace | 115 to 140 |

These numbers show scale. They are not targets. The no-op test, not a line count, decides whether a sentence stays. To shrink a skill, first cut what the baseline already did right, then cut domain knowledge the comparison showed the model already has. What remains stays only if the agent can't find it by looking.

## Openings

Three shapes:

1. **Definition plus a bold leading word**: "A prototype is **throwaway code that answers a question**. The question decides the shape."
2. **Job statement**, often with one thing the skill does not do.
3. **No opening**: the first line is step 1.

An H1 is optional.

## Leading words on the page

- Borrow a word the model already knows. Bold and define it at first use, then repeat only the word.
- A skill may have several leading words around one domain. A single coherent metaphor set reads best.
- A maxim can serve as a leading phrase ("Make the change easy, then make the easy change.").
- Name a large exception with its own leading word and place it beside the rule it breaks.
- Name the listener's state rather than the output ("Wait", not "Be concise").
- Reuse words the user's CLAUDE.md, README and code already use.
- A coined word works only if it is clearly defined, and the definition costs tokens that a known word gets for free.

## Sentences

- Use second-person imperatives addressed to the agent, and refer to "the user" in the third person.
- Keep sentences short and plain, and let them be a little loose.
- Define with a colon: `**Seam**: a place where you can alter behaviour without editing in that place`.
- Open a rule in bold and follow it with the reason as a short clause: "**Don't add tests.** A prototype that needs tests is no longer a prototype."
- Give "Why" its own section only when the structure itself is counter-intuitive.
- Use bold in two places: the first definition of a word, and hard constraints.
- Use all-caps NOT rarely.
- Pick one spelling variant and keep to it.
- Include no history and no dates. Quantities relative to the model are fine ("about 150k tokens").

## Paragraphs, lists, tables

- **Paragraphs carry conditions**: branches, and where a human decision is expected.
- **Lists hold parallel items**: branches, candidate approaches, anti-patterns.
- **Tables hold the same shape repeated** three or more times with the same fields.
- **Orchestrators use numbered steps**: `## Process`, then `### 1. ...`, each step ending on "Done when".

## Common blocks

Blocks are named in the skill's own words. There are no fixed headings.

| Block | Looks like |
|---|---|
| Anti-patterns | Bold name plus one reason. Some end on a tell, others on the positive goal |
| Rules | Bold-led bullets |
| Principles | A few principles, or one paragraph of worldview |
| Glossary | `**Term**: definition. _Avoid_: synonyms.` |
| Rejected framings | The rejected frame, why, and what to use instead |
| Out of scope | What the skill deliberately does not do |
| Good / Bad pairs | The bad example followed by its reasons |
| Phrasings that fit the style | Sample sentences for the product |
| When this is the right shape | A few things a user would say, used as the branch test. The last one points to the other branch |
| Resuming | How to pick up from an earlier product without re-asking settled questions |
| Reference docs | A list of the sibling files and what each holds |

## Frontmatter and files

- Frontmatter: `name`, `description`, `disable-model-invocation`, `argument-hint`, or whatever subset the target repo's convention allows.
- The description's shape is a mechanism (SKILL.md step 3), not a style choice.
- Name sibling files in capitals when they are disclosed references or format files (`LOGIC.md`, `ADR-FORMAT.md`). Use lowercase for files that get copied into the user's repo.

## Examples

- Pair Good with Bad, and follow the bad one with its reasons.
- Give a complete, finished sample rather than a form of placeholders.
- Give sample sentences, not a description of the tone.
- For code, contrast `// Good` with `// Bad`.
- Write questions for the user verbatim, in quotes, in the body.

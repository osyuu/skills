# Writing templates

A template fixes the product's shape so a downstream reader (a person, a parser, the next skill) gets the same frame every run. It should fix the shape, not the content.

## Three kinds

| Kind | What it is |
|---|---|
| **Format file** | A sibling `{X}-FORMAT.md` holding a template plus its rules: when to write one, numbering, lazy creation, supersession |
| **Embedded output template** | A template in SKILL.md, wrapped in a tag such as `<spec-template>` |
| **Copy-then-edit file** | A file the user copies and changes, such as a script with a marked library section, or a config seed |

## Where the template lives

Put it where it is already in context when the step that needs it runs.

1. **Copied and then edited**: its own file. Its reader is the person who copies it, not this run.
2. **Written on every run**: the template and its rules stay in SKILL.md, even if that makes the file long. The writing step has to see them for the fields to steer its reasoning.
3. **Written only on some runs** (a secondary product): a format file. Its rules and its "when to write one" criteria go with it.
4. **Lower bound**: a few lines that one step needs at the moment it runs stay in SKILL.md. Moving content out has to be worth the extra hop.

A skill with two products decides separately for each one.

## Fix the shape, leave the content

- **Placeholders state intent, not blanks.** One sentence sets the content, the point of view and the length: "The problem that the user is facing, from the user's perspective." A bare `{description}` gets filled with boilerplate.
- **Guidance comments inside the template** are fine: `<!-- in-scope unknowns you can't ticket yet -->`.
- **A complete example can replace placeholders** when tone matters more than fields. A good example next to a bad one, with the bad one's reasons, teaches the most.
- **Declare the minimum form**: "That's it. It can be a single paragraph." and "Only include these when they add genuine value." Without these lines, every optional field gets filled.
- **One constraint outside the template for every form**, with its reason and its exception ("avoid file paths: they go stale fast. Exception: ...").
- **Wrap it in a tag** so the model can tell which text is the shape to copy and which is the rule about it.
- **Map completion criteria to sections** when a section must not come out empty.
- **Mark the boundary in a copy-then-edit file**: "Everything above this marker is library: do not hand-edit."

## Every field steers the reasoning

The model thinks about what the fields ask for. To make it think of something, give that thing a field. A field left out means the thing never gets considered.

- Acceptance criteria that don't have to be able to fail come back already true before any work starts. Ask for "the observation that would show it false" instead.
- A template built around user stories, used for a refactor, produces stories nobody asked for around decisions that are really about interfaces and invariants. Give each product type a template that fits it.

A format file's skeleton is in [SKELETONS.md](SKELETONS.md) section 5.

## Placeholder syntax

Pick two forms and keep to them: `{name}` for short fields, and a sentence of intent for whole passages.

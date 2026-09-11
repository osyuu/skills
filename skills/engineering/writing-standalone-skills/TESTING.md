# Testing protocol

Three runs use this file. The **baseline** (SKILL.md step 2) shows where an agent without the skill fails. The **comparison** (step 6) runs the draft and the baseline side by side. The **clean run** (step 7) checks that the product works on a machine that has nothing of yours. All three use the clean-run command below.

## Fixture

A small situation you can rebuild: a throwaway repo, some fake data. Give it at least three cases:

- **the predicted failure**: the case where you expect the baseline to go wrong;
- **a user decision**: a point where the right move is to ask;
- **a control**: a case the model should get right anyway. If its behaviour changes under the skill, the skill is binding blindly.

A task that has to read a real repo (a survey, a review) uses one fixed commit, read-only.

## Runs

1. **Run both copies with the clean-run command.** The with-skill copy has the draft installed; the baseline copy doesn't. A sub-agent inherits your CLAUDE.md and your skills, so it is not a baseline. Use the same model and the same task sentence for both.
2. **The runner stops at the first decision that belongs to the user.** It writes the question down and doesn't simulate the answer. A simulated answer tests your guess about the user, not the skill. It also keeps a trace: what it read, what it did, and where it hesitated.
3. **Check hard boundaries.** For a read-only task, look at `git status` (or the equivalent) at the start and at the end.
4. **Compare case by case**, as in SKILL.md step 6. A case that is right in the baseline stays unbound.
5. **Use a blind judge when comparing several drafts.** The judge doesn't know where each draft came from. The rubric is written in advance and says what it favours. The judge checks claims in the output against the repo rather than judging how they read. The ranking is reported as a judgement, not a fact.
6. **Report the limits:** how many runs, which models, how many judges. A single run supports "on this fixture, with this model", nothing broader. Don't keep revising until a run comes back clean.

## Clean run

This command runs Claude without your global instructions, your settings, your skills, your plugins or your memory.

```sh
# in the fixture repo (a fresh one needs a commit first: git commit --allow-empty -m init)
wt="$(mktemp -d)/clean"
git worktree add "$wt" HEAD
mkdir -p "$wt/.claude/skills"
cp -R <path/to/product-skill> "$wt/.claude/skills/<name>"   # skip for the baseline copy
cd "$wt"
CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude -p "/<name> <args>" \
  --setting-sources project,local --settings '{"autoMemoryEnabled":false}' \
  --allowedTools "<tools the product needs>"
```

Keep the prompt directly after `-p` and `--allowedTools` last: it takes several values and swallows anything after it, and `claude` then exits with "Input must be provided".

1. **First verify, with a no-tools probe, what the session sees.** Use the same environment variable and flags, and a prompt like "Without using any tools, list the CLAUDE.md files, skills, MCP servers and memory entries in your context." The session must see the project CLAUDE.md and the project skills (the product among them, unless this is the baseline). It must see no user CLAUDE.md, no user skills, no plugin skills, no memory entries, and no MCP server the reader wouldn't have. If it saw your setup, the run tests your machine, not the reader's.
2. Then run the task.

- **Install it the way the reader will.** If the product ships in a plugin, load that plugin with `--plugin-dir <plugin-root>` instead of copying the folder, so its calls to sibling skills resolve under the names the reader sees. If it ships as loose skills, copy the siblings it calls too.
- `--setting-sources project,local` excludes your user CLAUDE.md, your user settings (including your permission rules), your user skills, and every plugin you enabled. The project's CLAUDE.md, its `.claude/skills/` and its project settings still load.
- **Auto-memory is not a setting source.** A worktree shares its repo's memory, so without the two memory switches above the run still reads your memory entries.
- **Built-in harness skills still load.** If the product calls a skill whose name a built-in also uses, the call reaches the built-in and appears to work. Read the transcript to see which skill actually ran.
- **Invoke the product the way its reader will**: `/<name>` as the prompt for a user-invoked skill, or a natural task prompt for a model-invoked one. The baseline gets the same task as a plain prompt. Confirm in the output that the skill loaded. If it didn't load, the run tested nothing.
- **Grant tools in the command.** Your allow rules don't come along, and a refused tool looks like a product failure. Use `--allowedTools`, or `--permission-mode` inside the throwaway worktree. Writes under `.claude/` still need approval under `--permission-mode acceptEdits`, and a `-p` session has nobody to give it. A session that has to install a skill writes it somewhere else and reports the path, and you copy it in.
- **One turn per call.** The runner stops at the first user decision on its own. To answer and continue, run `claude -p --continue "<answer>"` from the same directory, with the same environment variable and flags.
- **A `claude -p` session exits when its turn ends.** Jobs it started in the background keep running, but nothing waits for them or reads their results. When a `-p` session runs the fixtures itself, it must run them in the foreground within the same turn.
- `--bare` doesn't work here: it needs API-key auth and skips the project CLAUDE.md. `--safe-mode` doesn't either: it disables project skills, and those include the product.
- Clean up with `git worktree remove --force "$wt"`.

A clean run passes when the product reaches its first user decision, or finishes, without asking for or reaching for anything the reader's machine wouldn't have.

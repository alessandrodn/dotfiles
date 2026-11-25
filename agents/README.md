# agents

`AGENTS.md` is my personal working-style profile, shared by every coding agent.

Setup on a new machine:

```sh
ln -s ~/Developer/dotfiles/agents/AGENTS.md ~/.codex/AGENTS.md                # Codex
echo '@~/Developer/dotfiles/agents/AGENTS.md' >> ~/.claude/CLAUDE.md          # Claude Code
```

Claude Code gets an `@` import instead of a symlink, because it skips a symlinked `~/.claude/CLAUDE.md` in Cowork sessions.

`skills/` holds my workflows (e.g. `workspace-sync`) as [Agent Skills](https://agentskills.io): one `skills/<name>/SKILL.md` per skill, with `name` and `description` frontmatter. Invoke one with `/<name>` in Claude Code or `$<name>` in Codex.

```sh
for dir in ~/.claude/skills ~/.agents/skills; do                              # Claude Code, Codex
  mkdir -p "$dir"
  for s in ~/Developer/dotfiles/agents/skills/*/; do ln -sfn "${s%/}" "$dir/"; done
done
```

Each skill is linked on its own, so both folders can also hold local or tool-installed skills that stay out of this repo. Re-run the loop after adding a skill; it is safe to repeat. The links point at this checkout, so the live skills follow whatever branch is checked out.

Tests use [bats](https://github.com/bats-core/bats-core) (`brew install bats-core`). Run them before committing; there is no CI:

```sh
bats agents/skills/*/tests
```

A skill's script tests sit next to its scripts, in `skills/<name>/tests/test_<script>.bats`, with their own helpers, so each skill folder is self-contained. On macOS, bats runs under bash 3.2, where a failing `[[ ... ]]` that isn't a test's last line doesn't fail the test: end it with `|| false`.

If `AGENTS.md` grows large (Codex caps it at 32 KiB), split it into `style/*.md` and reference each file twice: `@style/x.md` (which Claude Code loads) and "Before X, read style/x.md" (which other agents follow on demand).

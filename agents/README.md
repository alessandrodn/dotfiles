# agents

`AGENTS.md` is my personal working-style profile, shared by every coding agent.

Setup on a new machine:

```sh
ln -s ~/Developer/dotfiles/agents/AGENTS.md ~/.codex/AGENTS.md                # Codex
echo '@~/Developer/dotfiles/agents/AGENTS.md' >> ~/.claude/CLAUDE.md          # Claude Code
```

Claude Code gets an `@` import instead of a symlink, because it skips a symlinked `~/.claude/CLAUDE.md` in Cowork sessions.

If `AGENTS.md` grows large (Codex caps it at 32 KiB), split it into `style/*.md` and reference each file twice: `@style/x.md` (which Claude Code loads) and "Before X, read style/x.md" (which other agents follow on demand).

# How I approach engineering work

> **This file is hosted in a public repository.** It must contain only general working principles. Never add sensitive information: no employer, customer, product, repo or project names, no links to private resources, no code, data, credentials, hostnames, or quotes from internal discussions. When adding a rule learned from real work, state the general principle only.

Personal profile for coding agents (Claude Code, Codex, and others). It describes *how* I approach and solve problems, so your output is something I can review and test the way I would my own.

Repository instructions (a project `AGENTS.md`/`CLAUDE.md`, PR templates, contribution guides) take precedence where they are more specific.

Rules are tagged `[confirmed]` (I agreed to it explicitly) or `[draft]` (inferred from my past work; follow it, but flag it if it seems wrong for the case at hand).

When I correct your approach, propose a new or amended `[draft]` rule for this file.

## Approach

### Look for established approaches before inventing one `[confirmed]`
Before designing a custom solution, check for recognized standards, tools or prior art, and cite them in the plan. Adopt one when it fits; justify it when you deviate.

### Fix the real defect, not the symptom `[draft]`
Find the root cause before changing code. If the first approach turns out to be wrong, restart from a clean design rather than patching the patch.

### Trace the mechanism and write it down `[draft]`
Explain step by step *why* the problem happens (code path, build behavior, tool resolution) so a reviewer can verify the reasoning without re-deriving it.

### Check the blast radius `[draft]`
Before changing shared behavior, check the effect on other platforms, consumers and release branches, and state the result.

### Make scope explicit `[draft]`
Name what is out of scope. Nearby bugs and "proper long-term fixes" become listed follow-ups, not part of the change.

## Choosing solutions

### Prefer the simplest, easily reproducible solution `[confirmed]`
Choose the smallest correct change. Avoid extra scripts, generators and tooling when a plain file or a convention does the job. If you rejected a simpler or more complex alternative, say which one and why.

### Generalize only for known growth `[confirmed]`
Use the simplest form until a second case is concretely expected. Once it is, design so the new case needs no schema or API change (e.g. a map instead of fixed fields).

### One source of truth `[draft]`
Put repeated code or config in one shared place and vary only what differs, so a future change happens once.

### Respect layering `[draft]`
Keep platform- or vendor-specific code in its own layer, not behind conditionals in shared code. Put each responsibility in the component that owns it.

### Delete what is not needed `[draft]`
Remove dead code, unused functions and unused dependencies, and ask whether a whole dependency can go.

### No silent behavior changes `[draft]`
A refactor preserves behavior. If behavior changes (return values, early exits, file locations, ordering), call it out and check who depends on it.

### Names say what things do `[draft]`
Pick names that describe the actual effect and avoid ambiguous abbreviations.

### Handle edge and failure paths explicitly `[draft]`
Check bounds, invalid handles, error and exception paths, and concurrency on shutdown. The "theoretically fine" paths are where crashes come from.

### Keep secrets out of output `[draft]`
Never log or print secrets or tokens. Use a hash or an identifier when correlation is needed.

## Testing and evidence

### Test everything that can be tested `[confirmed]`
Logic changes get automated tests. Scripts, build and config changes get an automated check too when feasible; when it is not, provide concrete manual evidence.

### Bug fixes start with a failing test `[draft]`
Add a regression test that fails while the bug is present, and commit it before the fix.

### If you skip a test, say why `[draft]`
State why a test isn't worth it here and how the change was verified instead. No tests written only to have tests.

### Show measured evidence `[draft]`
Back claims with numbers and artifacts: input/output tables, configuration matrices, before/after sizes or timings, device or emulator runs, screenshots.

### Pending verification means draft PR `[confirmed]`
A PR may be opened before all verification is done (e.g. on-device), but only as a draft with the pending items clearly unchecked. Mark it ready once they're verified.

## PRs and commits

### One concern per PR `[confirmed]`
Always split: minimal fixes, cleanups and refactors go in separate PRs, with no "since we're here" additions. List the rest as follow-ups. Large migrations are split per component or platform.

### Small commits that build `[confirmed]`
Each commit is a small unit of work, builds on its own, and has a very brief message. Follow the repository's headline convention (e.g. `component: imperative summary` or conventional commits).

### PR description: repo template first `[confirmed]`
Use the repository's PR template if one exists. Otherwise: What / Why / Approach (with rejected alternatives) / How tested / Out of scope. Always link the issue.

### Close the loop on review `[draft]`
Reply in each review thread, then rebase, retest, and say that you did. Expect automated or agent reviewers too, and address their findings explicitly.

## Reviewing others' work

### Review tone `[draft]`
Lead with what is good. Phrase points as questions ("why not…?", "have you considered…?"). Mark non-blocking items as such ("personal taste", "fine to leave for now"). Focus on design (layering, ownership, duplication) before details.

### Ask for real verification `[draft]`
Ask whether the scenario was actually exercised, not just whether CI is green.

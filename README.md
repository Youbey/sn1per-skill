[![skills.sh](https://skills.sh/b/Youbey/sn1per-skill)](https://skills.sh/Youbey/sn1per-skill)

# sn1per-skill

An [Agent Skill](https://agentskills.io) that teaches AI coding agents — **MiMoCode, Claude
Code, Codex, Cursor, Gemini CLI, OpenCode, Copilot**, and [75+ others](https://skills.sh) —
to drive the [Sn1per](https://github.com/1N3/Sn1per) automated penetration-testing framework
for **authorized** security testing.

Once installed, you can say things like:

> "Run a sn1per scan against my local nginx"
> "Analyze the smoketest loot and summarize the findings"
> "Scan example.com with the stealth mode" *(after confirming you're authorized)*

…and the agent knows how to build the container, run `sniper`, collect the loot, and
summarize results.

## What's inside

- **`SKILL.md`** — authorization guardrails first (refuses unauthorized targets, gates
  intrusive modes like `nuke`/`mass*`/bruteforce behind explicit opt-in), then the full
  workflow: build → lab target → scan → collect loot → validate → summarize.
- **`references/`** — complete mode/flag matrix with gotchas, loot layout guide, and
  troubleshooting (rootless vs rootful podman, build failures, resume files).
- **`scripts/build-image.sh`** — builds the `sn1per-kali-linux` podman image, patching two
  upstream Dockerfile bugs that break any non-interactive build (interactive `install.sh`
  prompt; dead Arachni download URL).
- **`scripts/validate_workspace.sh`** — deterministic loot-workspace sanity check the agent
  runs before summarizing results.

## Requirements

- Linux with [podman](https://podman.io/) (rootful fallback documented in the skill)
- A checkout of [1N3/Sn1per](https://github.com/1N3/Sn1per) (the image is built from its Dockerfile)
- An AI coding agent that supports Agent Skills

## Install

```bash
npx skills add Youbey/sn1per-skill
```

Pick your agent when prompted (symlink install is the default — single source of truth,
easy updates). Variants:

```bash
npx skills add Youbey/sn1per-skill -a claude-code    # → .claude/skills/
npx skills add Youbey/sn1per-skill -a opencode       # → .agents/skills/ (MiMoCode reads this)
npx skills add Youbey/sn1per-skill -g                # global (all projects)
npx skills add Youbey/sn1per-skill --list            # just list what's in the repo
```

**Manual install (no Node required):** copy the skill folder into a location your agent
scans:

```bash
# MiMoCode / any .agents-skill reader (project scope)
cp -r skills/sn1per <your-project>/.agents/skills/

# Claude Code
cp -r skills/sn1per <your-project>/.claude/skills/
```

## Usage

1. Make sure you're working in (or pointing the agent at) your Sn1per checkout.
2. Ask your agent to run a scan — it loads this skill automatically when relevant.
3. The skill only proceeds against targets **you confirm you're authorized to test**;
   its local nginx lab target is always allowed.

## Updating

```bash
npx skills update
```

## Development

The canonical copy lives in this repo at `skills/sn1per/`. If you keep a project-level
copy (e.g. inside a Sn1per checkout for your agent's convenience), sync with:

```bash
rsync -a --delete skills/sn1per/ <sn1per-checkout>/.agents/skills/sn1per/
```

CI validates that the `skills` CLI discovers the skill on every push.

## License & disclaimer

[MIT](LICENSE)

Unofficial and not affiliated with Sn1perSecurity LLC. Sn1per itself is distributed under
its own [license](https://github.com/1N3/Sn1per/blob/master/LICENSE.md) — review it before use.
This skill is intended solely for authorized security testing.

# gaffa-for-ai

Five agent skills for building on the [gaffa.dev](https://gaffa.dev) browser-automation REST API, plus the Gaffa docs MCP server, installable as one plugin.

| Skill | Entry | What it does |
|---|---|---|
| `gaffa-authoring` | auto-invokes on a gaffa coding prompt | Writes, edits, ports, or reviews code that calls the gaffa API. Loads verified facts and live docs before generating code. |
| `gaffa-find` | `/gaffa-find` | Iteratively discovers and extracts one piece of information from a target site, given a URL and a plain-language goal. |
| `gaffa-debug` | `/gaffa-debug` | Diagnoses a failing request or `brq_*` id from its recording and proposes a minimal patch. |
| `gaffa-bulk` | `/gaffa-bulk` | Runs one extraction across many known URLs with plan-aware concurrency, retries, dedup, and resumable state. |
| `gaffa-support` | `/gaffa-support` (slash only) | Helps when stuck: tries to resolve the problem first, then packages a redacted local report to email to support. Slash only on Claude Code, Cursor, Codex and Copilot. Antigravity has no way to opt a skill out of automatic selection, so there the agent can still reach for it. |

## Install as a plugin

This repo is a plugin. Installing it brings in all five skills and registers the Gaffa docs MCP server in one step, so there is nothing to copy and nothing to configure.

For Claude Code and Codex, point the tool's plugin marketplace at this repository, then install the `gaffa` plugin from it. Cursor and Antigravity install differently and are covered below.

On Claude Code that is two commands:

```
claude plugin marketplace add https://github.com/GaffaAI/gaffa-for-ai
claude plugin install gaffa@gaffa --scope project
```

The full URL is deliberate. Claude Code clones the `owner/repo` shorthand over SSH by default, which fails without a GitHub SSH key.

Scopes are `user` (the default), `project`, which writes `.claude/settings.json` in the project you are working in and is shared with collaborators, and `local`, which writes `.claude/settings.local.json` in that same project and is not shared.

Two things worth knowing:

- Cursor has no command-line install. The plugin manifest is here and the plugin loads once Cursor has it, but adding it is a click in the app rather than something you can script.
- Updating differs by tool. Claude Code refreshes marketplaces in the background by default and updates an installed plugin with `/plugin update`, where `/plugin marketplace update` only re-pulls the catalog. The others need asking: `codex plugin marketplace upgrade`, `copilot plugin update`, `cursor-agent plugin marketplace update`.

Antigravity has no marketplace concept, so it installs by putting the plugin where it looks. Clone this repo into its plugins directory and restart:

```
git clone --depth 1 https://github.com/GaffaAI/gaffa-for-ai ~/.gemini/config/plugins/gaffa
```

That covers Antigravity 2.0 and the IDE. The CLI stages plugins under `~/.gemini/antigravity-cli/plugins/` instead, so use that path if you run `agy`.

For one project rather than the whole machine, clone into `.agents/plugins/gaffa` instead. To commit it for the team, drop the clone's own history first, otherwise git records a pointer to another repository and a teammate ends up with an empty directory:

```
git clone --depth 1 https://github.com/GaffaAI/gaffa-for-ai .agents/plugins/gaffa
rm -rf .agents/plugins/gaffa/.git
```

## Install by copying

Each skill is a self-contained folder that follows the open Agent Skills standard (a `SKILL.md` with `name` and `description` frontmatter), so it works in any tool that reads that format. Copy the folders you want out of `skills/` into the directory your tool reads:

| Tool | Project directory | Personal directory |
|---|---|---|
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Cursor (2.4+) | `.agents/skills/` or `.cursor/skills/` | `~/.agents/skills/` or `~/.cursor/skills/` |
| Codex CLI | `.agents/skills/` | `~/.agents/skills/` |
| GitHub Copilot | `.agents/skills/` | `~/.agents/skills/` |
| Antigravity | `.agents/skills/` | see below |

Antigravity's personal directory depends on which surface you run. Its own docs give `~/.gemini/config/skills/` for Antigravity 2.0, `~/.gemini/antigravity/skills/` for the IDE and `~/.gemini/antigravity-cli/skills/` for the CLI. The project directory is the same for all three, so prefer that one.

For example, to install `gaffa-authoring` into a project on Claude Code:

```
cp -r skills/gaffa-authoring .claude/skills/gaffa-authoring
```

Swap the target for your tool. Copy only the skills you want, they do not depend on each other. Restart or reload the tool after adding a skill so it picks them up.

Copying this way brings the skills but not the docs MCP server, which the plugin install registers for you. To add it by hand, point your tool at `https://gaffa.dev/docs/~gitbook/mcp`. It takes no authentication. The two config files in this repo are the shapes to copy: `.mcp.json` for Claude Code and Cursor, and `mcp_config.json` for Antigravity, which uses `serverUrl` where the others use a type and a url. Without it the skills fall back to fetching the docs over plain HTTP, which works and is just slower.

The agent selects a skill automatically from its `description` when the task matches. The slash commands in the table above are a Claude Code affordance. Codex reaches the same skills as `$gaffa-find` or through its picker. In other tools, describe the task and the agent invokes the right skill.

## Setup

Set up two things once before running the skills.

1. API key. The skills read the key from the `GAFFA_API_KEY` environment variable only. It is never prompted for, written to disk, or logged. Set it persistently rather than pasting it each session, for example `export GAFFA_API_KEY=...` in your shell profile. The key stays out of version control.
2. Network egress. The skills call `api.gaffa.dev` and read docs from `gaffa.dev`. Behind a sandbox or proxy that blocks outbound traffic, allow both hosts first, or requests fail as connectivity errors.

The first real request confirms the setup. A missing or invalid key returns a clear authentication error, and a blocked host surfaces as a connectivity error that points back to the egress step.

## Notes

- Gaffa has no official SDK. The skills emit REST calls in whatever language and library your project already uses.
- The gaffa docs MCP server makes documentation lookups faster. The plugin install registers it for you, and the copy-install section above covers adding it by hand.
- The skills spend gaffa credits. `/gaffa-find` and `/gaffa-bulk` enforce tunable cost caps set in each `SKILL.md`. `/gaffa-debug` spends credits only on an optional re-run after explicit confirmation. `/gaffa-support` spends no credits and makes no gaffa API call.

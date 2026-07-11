# Gaffa Claude Code skills

Five Claude Code skills for building on the [gaffa.dev](https://gaffa.dev) browser-automation REST API.

| Skill | Entry | What it does |
|---|---|---|
| `gaffa-authoring` | auto-invokes on a gaffa coding prompt | Writes, edits, ports, or reviews code that calls the gaffa API. Loads verified facts and live docs before generating code. |
| `gaffa-find` | `/gaffa-find` | Iteratively discovers and extracts one piece of information from a target site, given a URL and a plain-language goal. |
| `gaffa-debug` | `/gaffa-debug` | Diagnoses a failing request or `brq_*` id from its recording and proposes a minimal patch. |
| `gaffa-bulk` | `/gaffa-bulk` | Runs one extraction across many known URLs with plan-aware concurrency, retries, dedup, and resumable state. |
| `gaffa-support` | `/gaffa-support` (slash only) | Helps when stuck: tries to resolve the problem first, then packages a redacted local report to email to support. Never auto-fires. |

## Install

Each skill is a self-contained folder. To use one, copy it into a location Claude Code reads skills from:

- a project's `.claude/skills/<skill-name>/`, or
- your personal `~/.claude/skills/<skill-name>/`.

For example, to install `gaffa-authoring` into the current project:

```
cp -r gaffa-authoring .claude/skills/gaffa-authoring
```

Copy only the skills you want. They do not depend on each other.

## Setup

Set up two things once before running the skills.

1. API key. The skills read the key from the `GAFFA_API_KEY` environment variable only. It is never prompted for, written to disk, or logged. Set it persistently rather than pasting it each session, for example `export GAFFA_API_KEY=...` in your shell profile. The key stays out of version control.
2. Network egress. The skills call `api.gaffa.dev` and read docs from `gaffa.dev`. Behind a sandbox or proxy that blocks outbound traffic, allow both hosts first, or requests fail as connectivity errors.

The first real request confirms the setup. A missing or invalid key returns a clear authentication error, and a blocked host surfaces as a connectivity error that points back to the egress step.

## Notes

- Gaffa has no official SDK. The skills emit REST calls in whatever language and library your project already uses.
- The optional gaffa docs MCP server at `https://gaffa.dev/docs/~gitbook/mcp` makes documentation lookups faster. The skills fall back to live HTTP doc fetches when it is not configured.
- The skills spend gaffa credits. `/gaffa-find` and `/gaffa-bulk` enforce tunable cost caps set in each `SKILL.md`. `/gaffa-debug` spends credits only on an optional re-run after explicit confirmation. `/gaffa-support` spends no credits and makes no gaffa API call.

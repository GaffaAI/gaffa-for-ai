---
name: gaffa-authoring
description: Use when the user mentions gaffa in a programming context (a gaffa.dev URL, a gaffa endpoint, or an existing gaffa API call) and wants concrete code. Writes, edits, ports, or reviews code that calls the gaffa.dev browser-automation REST API, loading the verified gaffa API facts and live docs first. For triaging a failing request or a brq_* id, /gaffa-debug leads instead. For a URL with only a vague goal and no script, /gaffa-find leads. For a known list of URLs with one shared goal, /gaffa-bulk leads.
---

# gaffa authoring

Helps a developer write, edit, port, or hand-review code that calls the gaffa.dev browser-automation REST API. Gaffa is a plain HTTP REST API with no official SDK. You emit code in whatever language and style the developer's project already uses.

## Critical gaffa facts (grounding)

For anything beyond them, consult the live docs (see Doc-fetching strategy).

1. Auth header is `X-API-Key: <key>`. Read from `GAFFA_API_KEY` env var. Never hard-code.
2. `POST /v1/browser/requests` is async by default. Returns an id. Poll `GET /v1/browser/requests/{id}`. Opt into sync with `"async": false`.
3. Max runtime is plan-tiered (1 / 2 / 5 min) for both sync and async. Always set `settings.time_limit` explicitly.
4. `parse_json` is token-priced, so its cost scales with the content parsed rather than being a flat per-call charge. Stored `/v1/schemas` extractions run the same `parse_json` action and are priced the same way. Check the live docs for the current model and token rates. Other actions are deterministically priced.
5. Request recordings (`settings.record_request: true`) are strongly recommended for `/gaffa-debug`. Without one, the skill can only suggest re-running the failing request with recording enabled. Plan-tiered retention applies (7 days / 30 days / 3 months).

The API base URL is `https://api.gaffa.dev`. Every `/v1/...` endpoint is called on that host. The documentation and the docs MCP live on `https://gaffa.dev`. API responses are wrapped in a top-level `data` object, so read fields as `data.id`, `data.state`, `data.credit_usage`, and `data.actions`. A finished request has `data.state` equal to `completed`. Each action result is a URL in `data.actions[].output`. The gaffa edge rejects some default HTTP-client User-Agents (for example Python `urllib`) with a 403, so emitted code should set an explicit `User-Agent` header. curl works with its default User-Agent. In the request body, `actions`, `time_limit`, and `record_request` go under `settings`, while `url`, `async`, `max_cache_age`, and `proxy_location` are root-level. `time_limit` is in milliseconds. The `parse_json` action uses a structured `data_schema` of the form `{name, description, fields: [{type, name, description}]}`, never a flat object and never a `schema` or `prompt` field. An optional `instruction` parameter sits beside `data_schema` (not inside it) for extra parsing guidance. `/v1/schemas` is an endpoint for reusable stored schemas, not an action type. LLM-backed extraction runs through the `parse_json` action, with an inline `data_schema` or a stored `data_schema_id`, and there is no separate schema action type. `parse_json` is not the only way to get data off a page, see "Choosing an extraction action" below. On a large content-rich page, `parse_json` over the full DOM can fail with `action_failed` (verified on Wikipedia), so narrow the input with a `selector` for the region that holds the data, or set `input_token_cap`.

### Verified endpoint and field reference

- Endpoints: `POST/GET /v1/browser/requests`, `GET /v1/browser/requests/{id}`, `POST/GET /v1/schemas`, `PUT /v1/schemas/{id}`, `DELETE /v1/schemas/{id}`, `POST/GET /v1/site/map`, `GET /v1/site/map/{id}`. The path is singular `map`, easy to typo as `maps`. Schema update and delete both take the id in the path.
- Settings fields under `settings`: `actions`, `time_limit`, `record_request`, `max_media_bandwidth`, `block_ads`. `max_cache_age` and `proxy_location` are root-level body fields, not under `settings`.
- Set `max_cache_age: 0` to disable the cross-user cache. For a non-zero value, confirm the unit against the live docs.
- If `time_limit` is not set, it defaults to your plan's maximum runtime, and it must stay below that maximum. Set it explicitly so the value is visible and intentional.
- Available actions: `click`, `scroll`, `type`, `wait`, `capture_cookies`, `capture_dom`, `capture_screenshot`, `capture_snapshot`, `download_file`, `generate_markdown`, `generate_simplified_dom`, `parse_json`, `print`, `block_dom_removals`, `capture_element`, `parse_table`. The per-action parameter catalog lives in `references/actions.md`. Read it on demand when you need a specific action's parameters.
- Proxy locations are residential IPs: `us`, `ie`, `sg`, `fr`. Set `proxy_location` to route through a residential IP in that country. With none set, the request uses a generic datacenter IP.

### Choosing an extraction action

Pick the action before you look up its parameters. `parse_json` is LLM-backed, so it is token-priced and its output can vary between runs. Weigh that against a deterministic path first, and tell the developer the trade-off you took so they can overrule it.

- Prefer a deterministic path when the value sits in a stable, well-structured place. Cheaper, repeatable, identical every run. Good for a price in a known element, a list of cards with a consistent shape, a field in a JSON blob. The options, in rough order of how often they fit:
  - `parse_table` with a `selector` for a table, which returns the rows already structured.
  - `generate_markdown` with a `selector` for the region, then parse the markdown in the developer's own language. Good for repeating cards or list items, and your recon capture is often this already.
  - `capture_element` with a `selector` for one specific element.
- Reach for `parse_json` when the value is buried in free text or moves around from page to page (a salary somewhere inside a job description), or when the task is interpretive rather than a lookup (summarising, classifying). That is where the LLM earns its cost.
- Do not use `parse_json` when the developer needs identical output across runs.

## Preferences

General preferences for using the Gaffa API. They capture guidance beyond the API docs, and we add to them over time. Follow them unless the specific task calls for something else.

- Prefer an inline `data_schema` over a stored `data_schema_id` for `parse_json`, so the end user can see the shape of what is being extracted. Reach for a stored `data_schema_id` only when a shape is registered server-side for reuse across separate scripts or sessions.

## Credential hygiene

These rules apply to every line of code and every message this skill produces.

1. Read `GAFFA_API_KEY` from env only. Never hard-code in emitted code. Reference it as `${GAFFA_API_KEY}`.
2. Never echo, log, narrate, or persist the value of `GAFFA_API_KEY`. Never put it in a URL or query string.
3. Before showing a gaffa recording, error trace, or request body to the user, to an LLM judge, or to disk, strip the values of any fields whose names match (case-insensitive, including vendor-prefixed variants like `gaffa_api_key`): `Authorization`, `X-API-Key`, `api_key` (and `apiKey`, `api-key`), `cookie`, `set-cookie`. Replace the value with `<REDACTED>`.
4. If the runtime value of `GAFFA_API_KEY` appears as a substring anywhere in a payload you are about to show or persist, replace it with `<REDACTED>`. Only enable this substring scrub when the env value is at least 16 characters long and contains both a digit and a letter. Otherwise skip and warn the developer on first invocation that the entropy floor was not met (field-name and prose rules still apply).
5. Persisted writes (the `/gaffa-find` reasoning log `./.gaffa-find-<timestamp>.log`, the `/gaffa-bulk` state file `./.gaffa-bulk-<run-id>/state.json`, and any other on-disk artifact) go through redaction first, then to a tempfile, then atomic-rename to the final path. A crash mid-write must not leave a plaintext-secrets file on disk.
6. If unsure whether a string is a secret, redact it.

## Doc-fetching strategy

Resolve documentation queries in two tiers, in order.

1. Preferred: gaffa docs MCP server at `https://gaffa.dev/docs/~gitbook/mcp`. When the developer has it configured, call its tools directly. `searchDocumentation` (param `query`, a string) for "how do I do X" questions. `getPage` (param `url`, a full URL) to fetch one page when you already have its URL.
2. Fallback: live HTTP fetch. `?ask=` against the docs for narrow lookups, `https://gaffa.dev/docs/llms.txt` for breadth, `https://gaffa.dev/docs/sitemap.md` for the full page index. Per-call timeout of 5 seconds. Used when the MCP is not configured or returns an error.

MCP availability probe, once per session, cached, total budget 10 seconds:

1. JSON-RPC `initialize` over POST. Confirms the endpoint speaks MCP.
2. Send the mandatory `notifications/initialized` notification.
3. JSON-RPC `tools/list` over POST. Confirms `searchDocumentation` and `getPage` (or at least one) are present.

Per-call MCP timeout is 5 seconds. If two consecutive calls in one session time out, demote to live HTTP for the rest of the session and tell the developer once.

If both tiers fail before any code is emitted, refuse with a clear message rather than guessing from training data. Both tiers read from `gaffa.dev`, so when they fail together the usual cause is that `gaffa.dev` is blocked by the environment's egress policy, separate from `api.gaffa.dev`. The message names that first: "Live gaffa docs are unavailable. If `gaffa.dev` is blocked by your environment's egress or proxy policy, allow it and retry, see the setup section in the skills README. Otherwise retry, or consult https://gaffa.dev/docs manually." If no gaffa MCP was configured, the message also suggests registering `https://gaffa.dev/docs/~gitbook/mcp` for faster lookups.

## First action

Before emitting code, live-fetch the doc section relevant to the developer's request (MCP preferred, HTTP fallback), grounded by the critical facts above. Do not emit code before the relevant docs are confirmed or the grounding alone is sufficient and stated as such.

## Behavior

- Do not guess CSS selectors. When the code needs a selector (for `parse_json` with a `selector`, `capture_element`, `click`, `type`, or `wait`), do not infer it from the URL or from the existing code. First fetch the real page with gaffa using a `generate_simplified_dom` or `capture_dom` capture, read the actual elements, then write the selector from what is really there. If that fetch fails with a connectivity error, the page is unreachable, usually because egress to `api.gaffa.dev` is blocked, so point the developer at the egress setup instead of guessing. If you genuinely cannot fetch the page, mark the selector as unverified and tell the developer to confirm it rather than presenting a guess as correct.
- Gaffa requests work best when targeting a single URL with actions performed on that page. Multi-page workflows that require persistent session state across navigations are not well supported. When the developer's request implies that pattern, surface the limitation up front instead of trying to force it.
- Always set `settings.time_limit` explicitly in generated code, based on what the job is expected to take. You do not know the developer's plan max, so emit a code comment reminding the developer to verify the value fits their plan (Starter 1 min, Startup 2 min, Growth 5 min).
- For any request the developer may later want to debug or audit, set `settings.record_request: true` in the emitted code so `/gaffa-debug` has a recording to inspect within the retention window.
- Default to the async pattern (POST then poll the returned id). Use `"async": false` only when the developer asks for a blocking call and the expected runtime is well under the plan max.
- Read the template that matches the task and adapt it to the developer's language and library. They are starting points, not literal output.
  - `templates/async-poll.md` for the POST-then-poll pattern.
  - `templates/sync.md` for the blocking `"async": false` pattern.
  - `templates/schema-extraction.md` for `/v1/schemas` structured extraction.

### Schema design and SDK migration

- Schema design with `/v1/schemas`. Same authoring trigger, constrained to one endpoint. See `templates/schema-extraction.md`. Storing a schema uses the endpoint with a normal API key.
- Migration from Playwright, Puppeteer, or Selenium to gaffa. Read the foreign snippet, map each step to a gaffa action, and flag any step that relies on persistent multi-page session state as a known gaffa limitation.

---
name: gaffa-bulk
description: Use when the developer has a known list of URLs (a file, a glob, or an enumerated set) and one extraction goal to apply across all of them. Runs a bulk gaffa scrape with plan-aware concurrency, retries with backoff, deduplication, and resumable partial results.
---

# gaffa bulk scrape

Runs the same extraction across a known set of URLs with plan-aware concurrency, retries, deduplication, partial-failure handling, and resumable aggregation. Prevents the naive `for url in urls` loop that exceeds plan concurrency, drops partial results, has no retry, and blows the credit budget.

## Cost guardrail caps

The skill enforces the caps below.

- `CONCURRENCY` default `1` (matches the Starter plan). Startup developers set it to `3`, Growth to `10`.
- `CREDITS_PER_INVOCATION` default `50`. Caps total credits in one call and is the governing guardrail on a bulk job's size.
- `MAX_RETRIES` default `3`. Per-URL retry attempts on transient failures.

A 1000-URL bulk at 1 credit each exhausts the default credit cap of 50 immediately. The credit cap, not a request count, bounds the job, so surface its value in the first invocation output and pause for confirmation before the developer raises it in the cost caps section above for a larger run.

## Critical gaffa facts (grounding)

1. Auth header is `X-API-Key: <key>`. Read from `GAFFA_API_KEY` env var. Never hard-code.
2. `POST /v1/browser/requests` is async by default. Returns an id. Poll `GET /v1/browser/requests/{id}`. Opt into sync with `"async": false`.
3. Max runtime is plan-tiered (1 / 2 / 5 min) for both sync and async. Always set `settings.time_limit` explicitly.
4. `parse_json` is token-priced, so its cost scales with the content parsed rather than being a flat per-call charge. Stored `/v1/schemas` extractions run the same `parse_json` action and are priced the same way. Check the live docs for the current model and token rates. Other actions are deterministically priced.
5. Request recordings (`settings.record_request: true`) are strongly recommended for `/gaffa-debug`. Without one, the skill can only suggest re-running the failing request with recording enabled. Plan-tiered retention applies (7 days / 30 days / 3 months).

The API base URL is `https://api.gaffa.dev`. Every `/v1/...` endpoint is called on that host. The documentation and the docs MCP live on `https://gaffa.dev`. API responses are wrapped in a top-level `data` object, so read fields as `data.id`, `data.state`, `data.credit_usage`, and `data.actions`. A finished request has `data.state` equal to `completed`. Each action result is a URL in `data.actions[].output`. The gaffa edge rejects some default HTTP-client User-Agents (for example Python `urllib`) with a 403, so emitted code should set an explicit `User-Agent` header. curl works with its default User-Agent. In the request body, `actions`, `time_limit`, and `record_request` go under `settings`, while `url`, `async`, `max_cache_age`, and `proxy_location` are root-level. `time_limit` is in milliseconds. The `parse_json` action uses a structured `data_schema` of the form `{name, description, fields: [{type, name, description}]}`, never a flat object and never a `schema` or `prompt` field. An optional `instruction` parameter sits beside `data_schema` (not inside it) for extra parsing guidance. `/v1/schemas` is an endpoint for reusable stored schemas, not an action type. Extraction always uses the `parse_json` action, with an inline `data_schema` or a stored `data_schema_id`. On a large content-rich page, `parse_json` over the full DOM can fail with `action_failed` (verified on Wikipedia), so narrow the input with a `selector` for the region that holds the data, or set `input_token_cap`.

Plan-tiered concurrency is 1 / 3 / 10 parallel requests (Starter / Startup / Growth). The worker pool must never exceed `CONCURRENCY`.

## Credential hygiene

1. Read `GAFFA_API_KEY` from env only. Never hard-code in emitted code. Reference it as `${GAFFA_API_KEY}`.
2. Never echo, log, narrate, or persist the value of `GAFFA_API_KEY`. Never put it in a URL or query string.
3. Before showing a gaffa recording, error trace, or request body to the user, to an LLM judge, or to disk, strip the values of any fields whose names match (case-insensitive, including vendor-prefixed variants like `gaffa_api_key`): `Authorization`, `X-API-Key`, `api_key` (and `apiKey`, `api-key`), `cookie`, `set-cookie`. Replace the value with `<REDACTED>`.
4. If the runtime value of `GAFFA_API_KEY` appears as a substring anywhere in a payload you are about to show or persist, replace it with `<REDACTED>`. Only enable this substring scrub when the env value is at least 16 characters long and contains both a digit and a letter. Otherwise skip and warn the developer on first invocation that the entropy floor was not met (field-name and prose rules still apply).
5. Persisted writes (the `/gaffa-find` reasoning log `./.gaffa-find-<timestamp>.log`, the `/gaffa-bulk` state file `./.gaffa-bulk-<run-id>/state.json`, and any other on-disk artifact) go through redaction first, then to a tempfile, then atomic-rename to the final path. A crash mid-write must not leave a plaintext-secrets file on disk.
6. If unsure whether a string is a secret, redact it.

## Doc-fetching strategy

Resolve documentation queries in two tiers, in order.

1. Preferred: gaffa docs MCP server at `https://gaffa.dev/docs/~gitbook/mcp`. `searchDocumentation` (param `query`) for "how do I do X". `getPage` (param `url`) to fetch one page by URL.
2. Fallback: live HTTP fetch. `?ask=` against the docs for narrow lookups, `https://gaffa.dev/docs/llms.txt` for breadth. Per-call timeout of 5 seconds.

MCP availability probe, once per session, cached, total budget 10 seconds: JSON-RPC `initialize`, then the mandatory `notifications/initialized` notification, then `tools/list` confirming `searchDocumentation` and `getPage` (or at least one). Per-call MCP timeout is 5 seconds. Two consecutive timeouts demote to live HTTP for the rest of the session, announced once.

If both tiers fail at job start, refuse with a clear message (and suggest registering the MCP if none was configured). If both tiers fail mid-flight with partial results already on disk, do not discard progress: return the partial results as `needs-human-review`, keep `state.json`, and surface the doc-fetch failure as the reason so the developer can resume.

## First action

Sketch a job topology before firing anything: resolve the URL set, confirm the single extraction goal, choose the action set, and compute the pre-flight credit estimate.

## Behavior

- Inputs. Required: a known URL set (file path, glob expansion, or pasted enumerated list) and one extraction goal. Optional: concurrency override, per-URL timeout, output filename. If the set is described but not yet enumerated (for example "every product page on acme.com"), run `/gaffa-find --reconnaissance-only` to enumerate the URLs first, then come back here.
- Plan-aware concurrency. The worker pool runs up to `CONCURRENCY` requests genuinely in parallel and never more. When `CONCURRENCY` is greater than 1, implement a real concurrent pool (async or threads), not a sequential loop that only reads the constant. At `CONCURRENCY` of 1 a sequential loop is correct. If the API returns 429, treat it as transient and back off.
- Keep `state.json` `pending` accurate. Move each URL out of `pending` into `completed` or `failed` as it finishes, so a finished run shows an empty `pending` rather than the full input list.
- Retry policy. Retry on transient failures (5xx, 408, 425, 429, network errors) with exponential backoff and a small random jitter, up to `MAX_RETRIES` attempts. Do not retry on 400, 401, 403, 404, which are configuration or permission issues that retrying will not fix. After the retry budget is exhausted, mark that URL failed and continue with the rest.
- Deduplication. Collapse duplicate URLs in the input set before scheduling so the same URL is not fetched twice.
- One POST per URL. Each POST is a fresh billed scrape, so read the id, state, credit usage, and all action outputs from that single response or from polling its id. Never re-submit the same URL just to read a different field. Doing so double-bills the URL and corrupts the credit ledger.
- Check per-action errors, not just `data.state`. A request can be `completed` while an action inside it failed (for example `parse_json` with `error: action_failed` and no `output`). Record that URL as a failed extraction with the action error in the NDJSON `error` field, not a silent `result: null, error: null` line.
- For content-rich pages, give `parse_json` a `selector` for the region that holds the data, or set `input_token_cap`. Running `parse_json` over the full DOM of a large page can return `action_failed`.
- Resumable. Progress is persisted to `./.gaffa-bulk-<run-id>/state.json`, including credits spent so far. On crash resume, the credit cap accounts for prior spend so a flapping run cannot quietly exceed the budget. The state file is written through the redaction-then-tempfile-then-atomic-rename path.
- Pre-flight credit estimate. Per-request estimate times N. Pause and ask for confirmation before the invocation total would breach `CREDITS_PER_INVOCATION`. For token-priced actions (`parse_json`, `/v1/schemas` extraction) gate against the upper bound of the estimate, not the midpoint. For `parse_json`, fetch current rates from https://gaffa.dev/docs/credits-and-pricing.md once per invocation, reuse that cached rate across the URL set, and add a 50% safety margin on output tokens. For `/v1/schemas`, pin a conservative ceiling at the worst current `parse_json` rate applied to the captured page size in tokens, tell the developer the ceiling is a guess, and ask for confirmation regardless of headroom.
- Output. NDJSON written to `./gaffa-bulk-<run-id>.ndjson` in the developer's working directory, one result per line. Each line records the URL, the extracted result or the failure reason, and the request id.
- Set `settings.time_limit` explicitly on every request and set `record_request: true` so failed URLs can be triaged later with `/gaffa-debug`.
- Abort. Ctrl-C ends the run. The latest `state.json` allows a resume.
- When the run ends in `needs-human-review` or with URLs that could not be recovered, end the output with one line: *Still stuck? Run `/gaffa-support` to get help or file a report.*

See `templates/job-plan.md` for the topology, worker-pool, retry, and state-file shapes.

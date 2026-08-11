# Template: bulk job topology

Language-agnostic shapes for the bulk orchestration. Adapt to the developer's language and runtime.

## Run directory layout

```
./.gaffa-bulk-<run-id>/state.json     progress and credit ledger, redacted, atomic-rename writes
./gaffa-bulk-<run-id>.ndjson          one result line per URL
```

## state.json shape

```json
{
  "run_id": "<run-id>",
  "goal": "extract product title and price",
  "concurrency": 3,
  "credits_spent": 12,
  "credits_cap": 50,
  "completed": ["https://a.example/1", "https://a.example/2"],
  "failed": [{ "url": "https://a.example/9", "reason": "404", "attempts": 1 }],
  "pending": ["https://a.example/3"]
}
```

`credits_spent` is the resume anchor. On restart, the credit cap subtracts prior spend so a flapping run cannot exceed `CREDITS_PER_INVOCATION`. Never write a key value into this file. Run the redaction pass, write a tempfile, then atomic-rename over `state.json`.

Keep `pending` accurate. Remove a URL from `pending` the moment it moves to `completed` or `failed`, so the persisted file reflects real progress. A finished run has an empty `pending`. Do not leave every URL in `pending` after they have been processed, because the file then looks like the run made no progress.

## NDJSON output line shape

```json
{ "url": "https://a.example/1", "request_id": "brq_x", "result": { "title": "Widget", "price": "9.99" }, "error": null }
```

A failed URL records `"result": null` and a non-null `"error"` with the failure reason.

## Worker pool rules

- Run up to `CONCURRENCY` requests genuinely in flight at once, never more. This matches the plan concurrency (1 / 3 / 10 for Starter / Startup / Growth). When `CONCURRENCY` is greater than 1, the worker pool must actually issue requests in parallel (a real pool, async, or threads), not a plain sequential loop that ignores the constant. At `CONCURRENCY` of 1 a sequential loop is correct. Exceeding the plan concurrency returns 429, which is a transient to back off on.
- One POST per URL. Each `POST /v1/browser/requests` is a fresh billed scrape. Read everything you need (`data.id`, `data.state`, `data.credit_usage`, and every `data.actions[].output`) from that single response, or from polling that same request id. Never submit a second request for the same URL just to read a different field, because that double-bills the URL.
- Check per-action errors, not just the request state. A request can have `data.state` of `completed` while an action inside it carries an `error` (for example `parse_json` returning `action_failed` with no `output`). Treat that URL as a failed extraction: record the action error in the NDJSON `error` field with `result` null. Do not write a silent `result: null, error: null` line, which looks like an empty success.
- For content-rich pages, give `parse_json` a `selector` for the region that holds the data (or set `input_token_cap`). Extracting over the full DOM of a large page can return `action_failed`.
- Deduplicate the input URL set before scheduling.
- Retry transient failures (5xx, 408, 425, 429, network) with exponential backoff plus a small random jitter up to `MAX_RETRIES`. The jitter spreads retries so concurrent workers do not all re-fire at once after a 429. Do not retry 400, 401, 403, 404. Decide transient versus permanent on the numeric HTTP status code itself, not by substring-matching the status number inside an error message, which can misclassify codes like 4008. Gaffa has no idempotency key, so a network-error retry can double-bill a URL whose POST already reached the server. Sum spend from the returned `credit_usage` values, not from the request count.
- A failed URL line in the NDJSON output uses `"result": null` and a non-null `"error"` with the reason. Do not write a result object full of null fields.
- After each completed request, update `credits_spent` from the response `credit_usage`, then write `state.json` atomically.
- Treat `CREDITS_PER_INVOCATION` as a hard ceiling. Before scheduling a URL, stop if `credits_spent` plus the per-request upper-bound estimate would exceed the cap. Leave the remaining URLs in `pending` and report the stop, so a single large run cannot overshoot the cap.
- Set `settings.time_limit` explicitly and `settings.record_request: true` on every request so failures are triageable with `/gaffa-debug`. Set an explicit `User-Agent` header so the request is not blocked with a 403.

## Per-request shape

Pick the extraction action before you copy either shape below, per the rule in `SKILL.md`. The same action runs on every URL in the set, so the choice is paid N times over.

Same fields from every page, in a stable place. Deterministic, so it costs the same on every URL and returns the same thing each run:

```bash
curl -sS -X POST https://api.gaffa.dev/v1/browser/requests \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{
    "url": "URL_FROM_SET",
    "max_cache_age": 0,
    "settings": {
      "time_limit": 60000,
      "record_request": true,
      "actions": [
        { "type": "generate_markdown", "selector": "main" }
      ]
    }
  }'
```

Fetch `data.actions[0].output` and parse the markdown into the NDJSON `result` object in the developer's own language. Use `parse_table` instead when the data is a table, or `capture_element` when it is one specific element.

Free-text or interpretive fields, where the value moves around from page to page. Token-priced per URL, so reach for it only when the deterministic path does not fit. Same request as above, swapping the `actions` array for:

```json
"actions": [
  {
    "type": "parse_json",
    "selector": "main",
    "data_schema": {
      "name": "role",
      "description": "Extract the salary from the job description",
      "fields": [
        { "type": "string", "name": "salary", "description": "the salary, wherever it appears in the prose" }
      ]
    }
  }
]
```

The `selector` narrows the input `parse_json` sees. Point it at the region that holds the data (for example `main`, `article`, or a specific container). On a large page, omitting it can make `parse_json` return `action_failed`. If a single selector does not fit every URL in the set, fall back to `input_token_cap` instead.

# Template: async request plus poll

The default gaffa pattern.
`POST /v1/browser/requests` returns an id immediately.
Poll `GET /v1/browser/requests/{id}` until `state` is terminal.

Language-agnostic shape shown with curl.
Adapt to the developer's language and HTTP library.
Keep `time_limit` explicit and read the key from the environment.

## Submit

```bash
curl -sS -X POST https://api.gaffa.dev/v1/browser/requests \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{
    "url": "https://example.com",
    "max_cache_age": 0,
    "settings": {
      "time_limit": 60000,
      "record_request": true,
      "actions": [
        { "type": "capture_screenshot" }
      ]
    }
  }'
```

The response is wrapped in a top-level `data` object, so the id is at `data.id`.
The 60000 ms above (60 seconds) is an example value, not the default.
If you omit `time_limit` it defaults to your plan's maximum runtime and must stay under that maximum.
Set it explicitly and raise it toward your plan max if the job needs longer (Starter 1 min, Startup 2 min, Growth 5 min).

## Poll

```bash
curl -sS https://api.gaffa.dev/v1/browser/requests/REQUEST_ID \
  -H "X-API-Key: ${GAFFA_API_KEY}"
```

Poll on an interval until the request is terminal.
Treat `data.state` of `completed` as success and a non-empty `data.error` as failure.
Keep polling on any other state rather than hard-coding a list of in-progress state names, since the exact in-progress vocabulary is not documented and a name you did not anticipate should not be misread as a failure.
Always bound the loop with a deadline so it cannot spin forever, for example `time_limit` plus a margin for queueing and network.
On reaching the deadline, stop and report a timeout rather than continuing to poll.
A finished run carries `data.actions` (each action result is a URL in `data.actions[].output`) plus `data.credit_usage`, `data.from_cache`, `data.started_at`, `data.completed_at`, `data.running_time`, and `data.page_load_time`.
A failed run carries `data.error` and `data.error_reason`.
If you set `record_request: true`, the response also carries `data.video`.

## Notes

- `record_request: true` lets `/gaffa-debug` inspect what happened later, within the plan-tiered retention window (7 days / 30 days / 3 months).
- `max_cache_age` is a root-level field, not under `settings`, and is in seconds.
  Set it to 0 to force a fresh fetch and bypass the cross-user cache.
- Never place the key in the URL or query string.
  It belongs only in the `X-API-Key` header.

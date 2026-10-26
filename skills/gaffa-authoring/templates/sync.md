# Template: synchronous request

Use only when the developer wants a blocking call and the expected runtime is well under the plan's sync cap.
Set `"async": false` in the request body.
The response comes back on the same call, so there is no id to poll.

```bash
curl -sS -X POST https://api.gaffa.dev/v1/browser/requests \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{
    "url": "https://example.com",
    "proxy_location": "us",
    "async": false,
    "max_cache_age": 0,
    "settings": {
      "time_limit": 60000,
      "actions": [
        { "type": "capture_dom" }
      ]
    }
  }'
```

## Notes

- The sync cap is plan-tiered: 60,000 ms (60s) on Pay As You Go and Starter, 90,000 ms (90s) on Startup and Growth.
  The async maximums differ: 60,000 ms (60s) on Pay As You Go and Starter, 120,000 ms (2 min) on Startup, 300,000 ms (5 min) on Growth.
  If the job can exceed the sync cap, prefer the async-poll template instead.
- Set the HTTP client read timeout above `time_limit` so the client does not abort a request that is still within its allowed runtime.
- Everything else (auth, `time_limit`, `record_request`, `max_cache_age`, `proxy_location`) behaves the same as the async pattern.

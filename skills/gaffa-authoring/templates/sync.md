# Template: synchronous request

Use only when the developer wants a blocking call and the expected runtime is well under the plan max.
Set `"async": false` in the request body.
The response comes back on the same call, so there is no id to poll.

```bash
curl -sS -X POST https://api.gaffa.dev/v1/browser/requests \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{
    "url": "https://example.com",
    "async": false,
    "max_cache_age": 0,
    "settings": {
      "time_limit": 60000,
      "record_request": true,
      "actions": [
        { "type": "capture_dom" }
      ]
    }
  }'
```

## Notes

- The plan-tiered max runtime (1 / 2 / 5 min) applies to sync calls too.
  If the job can exceed it, prefer the async-poll template instead.
- Set the HTTP client read timeout above `time_limit` so the client does not abort a request that is still within its allowed runtime.
- Everything else (auth, `time_limit`, `record_request`, `max_cache_age`) behaves the same as the async pattern.

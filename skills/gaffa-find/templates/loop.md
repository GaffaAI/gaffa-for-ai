# Template: find loop shapes

Language-agnostic shapes for the discovery loop.
Adapt to the developer's language.

## Reconnaissance: site map

```bash
curl -sS -X POST https://api.gaffa.dev/v1/site/map \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{ "url": "https://example.com" }'
```

By default the POST waits for the crawl and returns the links directly, or set `async: true` in the request body to get the request back immediately with state `pending` and poll `GET /v1/site/map/{id}` for the result.
`data.links` is the list of links found: each entry has a `url`, plus `extracted_text` and `similarity_score` when a `search_query` ranked them by similarity (best match first).
Without a `search_query`, entries are ordered alphabetically and only carry the `url`.
The response also carries `data.link_count`, `data.total_link_count`, `data.truncated` (true when the returned list is a subset of the total), `data.partial_failure` and `data.failed_sitemaps` (when one or more sitemap documents could not be fetched), `data.filters_applied`, `data.from_cache`, and `data.sitemap_built_at`.
Optional inputs besides `url` and `async`: `include` and `exclude` regex filters, `search_query` for semantic ranking (ranked results are capped at 50, and for very large sitemaps only the first links up to the account's searchable-links limit, default 50,000, are ranked), `limit` (defaults to the account maximum), and `embedding_model` (default `text-embedding-3-small`).
It takes a root-level `max_cache_age` in seconds, defaulting to 6 hours and capped by the server-side cache retention window (6 hours by default), so larger values are clamped, and 0 always rebuilds.
The path is singular `map`, not `maps`.
The map body takes no `proxy_location`, the crawl already goes out through residential proxies.
A mapping request has a maximum running time of 60 seconds, after which an error is returned.

## Reconnaissance: broad markdown capture

```bash
curl -sS -X POST https://api.gaffa.dev/v1/browser/requests \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{
    "url": "https://example.com",
    "proxy_location": "us",
    "max_cache_age": 0,
    "settings": {
      "time_limit": 60000,
      "record_request": true,
      "actions": [
        { "type": "generate_markdown" }
      ]
    }
  }'
```

The loop keeps `record_request: true` on its reconnaissance requests, drop it from the re-runnable script you hand back.
`proxy_location` stays in the re-runnable script, it is there to help the request succeed rather than for the reconnaissance.

## Targeted extraction with the parse_json action

Only reach for this once you have ruled out a deterministic path, per step 3 of the loop in SKILL.md.
LLM-backed extraction runs through the `parse_json` action, and there is no `/v1/schemas` action type.
Pass an inline `data_schema`, or reference a stored schema with `data_schema_id` after creating it via the `/v1/schemas` endpoint.

```bash
curl -sS -X POST https://api.gaffa.dev/v1/browser/requests \
  -H "X-API-Key: ${GAFFA_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: gaffa-skill/1.0" \
  -d '{
    "url": "https://example.com/leadership",
    "proxy_location": "us",
    "max_cache_age": 0,
    "settings": {
      "time_limit": 60000,
      "record_request": true,
      "actions": [
        {
          "type": "parse_json",
          "selector": "main",
          "data_schema": {
            "name": "leadership",
            "description": "Find the chief executive officer",
            "fields": [
              { "type": "string", "name": "ceo_name", "description": "the full name of the CEO" }
            ]
          }
        }
      ]
    }
  }'
```

The loop keeps `record_request: true` on this request too, drop it from the re-runnable script you hand back.
`proxy_location` stays, for the same reason as above.

`parse_json` is token-priced.
Gate it against the upper-bound estimate before firing.
Give it a `selector` for the region your recon identified, because `parse_json` over the full DOM of a large page can return `action_failed`.
If you do not yet know a good selector, your `generate_markdown` recon output often already contains the answer, so read that before spending another extraction request.

## Reasoning log

Append one entry per iteration to `./.gaffa-find-<timestamp>.log`.
One entry records the iteration number, the hypothesis, the request id, the candidate value, and the stop-condition decision.
Never write a key value into the log.

Write it safely.
The tempfile must live in the same directory as the final log so the rename is atomic on the same filesystem.
A tempfile in `/tmp` and a final log in the working directory are usually on different filesystems, which turns the rename into a non-atomic copy and defeats the crash-safety guarantee.

```bash
FINALLOG="./.gaffa-find-$(date +%Y%m%dT%H%M%S).log"
TMPLOG="${FINALLOG}.tmp"          # same directory as the final log, not /tmp

cat > "$TMPLOG" << 'EOF'
# gaffa-find reasoning log
... one entry per iteration ...
EOF

# redact only when the env value meets the entropy floor (16+ chars, a digit and a letter)
if [ "${#GAFFA_API_KEY}" -ge 16 ] && printf '%s' "$GAFFA_API_KEY" | grep -q '[0-9]' && printf '%s' "$GAFFA_API_KEY" | grep -q '[A-Za-z]'
then
  sed -i "s|${GAFFA_API_KEY}|<REDACTED>|g" "$TMPLOG"
fi

mv "$TMPLOG" "$FINALLOG"          # atomic rename within the same directory
```

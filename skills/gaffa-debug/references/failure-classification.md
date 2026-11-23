# gaffa failure classification

Map recording fields to a likely cause and the smallest fix.
Pull the recording with `GET /v1/browser/requests/{id}` and read these fields.
All fields live under the top-level `data` object in the response.
The field set includes `data.id`, `data.url`, `data.actual_url`, `data.state`, `data.credit_usage`, `data.http_status_code`, `data.from_cache`, `data.started_at`, `data.completed_at`, `data.running_time`, `data.page_load_time`, and `data.actions`.
Each action entry carries `id`, `type`, `custom_id`, `timestamp`, `output`, `reference` and `error`.
`output` is a URL by default or the content itself for `output_type: "inline"`.
A `loop` entry also carries `iterations` and a nested `actions` array.
When relevant the response also carries `data.error`, `data.error_reason`, `data.proxy_location`, and `data.session_continuation` (when session continuation is enabled).
`data.data_deleted: true` means the request is returned as metadata only.
Its actions, video and redirects are no longer available, and it is never served from cache.
With `log_redirects` set it also carries `data.redirects`.
With `record_request: true` it also includes `data.video`.
A finished request has `data.state` equal to `completed` whether it succeeded or not, `data.error` tells them apart.
A non-200 response carries `{"error": {"type", "id", "code", "message"}}`, except 401, which is the plain text `Invalid API Key`.

| Signal in recording | Likely cause | Smallest fix |
|---|---|---|
| `data.http_status_code` 4xx plus `data.error_reason` | gaffa API misuse (malformed body, bad field) | One-line patch to the offending field |
| `data.state` `completed` but an action `output` is empty | target-site DOM change vs wrong selector | Diff actions against a fresh capture, then correct the selector or accept the DOM moved |
| `parse_json` action has `error: action_failed`, no `output` | invalid `data_schema`, or `parse_json` run over the full DOM of a large page | Fix the schema to the structured form first. If the schema is valid, narrow the input with a `selector` or `input_token_cap` |
| `data.error_reason` matches bot detection or captcha | target-site bot protection | Set `proxy_location` (`us` by default) if the request had none, or try another location (`ie`, `sg`, `fr`) if one is blocked. Needs a paid account. Not a script change |
| a proxy or access error | the site is restricted on the proxy network | Retry the request once without `proxy_location` |
| `data.running_time` much greater than `data.page_load_time` | flaky timing | Add a `wait` action or raise `time_limit` |
| `data.error` is `request_timeout` and the open actions end `action_cancelled` | the request hit `time_limit` | Raise `time_limit` within the plan cap or trim the actions. A request cancelled this way is not billed |
| `data.from_cache: true` when fresh data expected | cross-user cache hit | Set `max_cache_age: 0` or change a parameter to bust the cache key |
| A `loop` action ends `action_timed_out` | its `timeout` covers all iterations together and ran out | Raise the loop `timeout` or lower the iteration count. Completed iterations keep their outputs, under the loop entry's `actions` array, and actions finished during the final incomplete pass are recorded too. The `iterations` count only includes passes that ran to completion |
| Actions after a `loop` end `action_cancelled` | the loop exited early and cancelled the rest | Set `continue_on_fail: true` on the loop so the actions after it still run |
| `data.data_deleted: true` | the request is returned as metadata only, past retention | Nothing to recover. Re-run the request if its outputs are still needed. Retention is 7 days / 30 days / 3 months by plan |

## Notes

- `max_cache_age` and `proxy_location` are root-level body fields, not under `settings`.
- Always scrub credential-named fields out of the recording before showing it.
- Prefer the smallest fix.
  A rewrite is rarely the right first move.

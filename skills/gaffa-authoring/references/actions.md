# gaffa action parameter catalog

Per-action parameters, fetched from the live gaffa docs. Read this on demand when you need a specific action's parameters. When in doubt, re-confirm against the live docs (`getPage` on the action's page under `/docs/features/browser-requests/actions/`, or the HTTP fallback), because the docs can change.

## Universal parameters (every action)

- `type` (string, required): the action type identifier, for example `capture_dom`.
- `continue_on_fail` (boolean, optional): continue the run if this action fails. Default `false`.
- `customId` (string, optional): a custom action identifier. Default `null`.

## Actions without outputs

### click
- `selector` (string, required): CSS selector for the element to click.
- `timeout` (integer, optional): max wait for the element. Default 5000 ms.

### scroll
- `percentage` (integer, required): scroll amount, range -100 to 100. Default 100.
- `wait_time` (integer, optional): monitor duration after the scroll. Default 0.
- `max_scroll_time` (integer, optional): max scroll duration. Default 20000 ms.
- `scroll_speed` (string, optional): one of `slow`, `medium`, `instant`. Default `medium`.
- `interval` (integer, optional): pause between scroll events in ms. Default 0.
- `timeout` (integer, optional): wait for a scrollable element. Default 0.
- `selector` (string, optional): element to scroll. Defaults to the page body.

### type
- `selector` (string, required): input field CSS selector.
- `text` (string, required): text to enter.
- `timeout` (integer, optional): max wait for the input field to appear. No default documented.

### wait
- `time` (integer, optional): milliseconds to wait.
- `selector` (string, optional): CSS selector to wait for.
- `timeout` (integer, optional): max wait for the selector. Default 5000 ms.

### block_dom_removals
- No parameters beyond the universal ones are documented.

## Actions with outputs

### capture_cookies
- No parameters beyond the universal ones are documented.

### capture_dom
- No parameters beyond the universal ones are documented.

### capture_screenshot
- `size` (string, optional): one of `view`, `fullscreen`. Default `view`.

### capture_snapshot
- No parameters beyond the universal ones are documented.

### capture_element
- `selector` (string, required): CSS selector for the target element.
- `timeout` (integer, optional): max wait for the element. Default 5000 ms.

### download_file
- `timeout` (integer, optional): max download wait. Default 5000 ms.

### generate_markdown
- `selector` (string, optional): CSS selector for a specific element.
- `output_type` (string, optional): one of `file`, `inline`. Default `file`.

### generate_simplified_dom
- No parameters beyond the universal ones are documented.

### print
- `size` (string, optional): paper size, `A4`. Default `A4`.
- `margin` (integer, optional): margin in pixels. Default 20.
- `orientation` (string, optional): one of `portrait`, `landscape`. Default `portrait`.

### parse_json
Token-priced, so surface cost as token-based, not deterministic. Check the live docs for the model and token rates.
- `data_schema_id` (string, required if `data_schema` is absent): a saved schema identifier.
- `data_schema` (json, required if `data_schema_id` is absent): an inline schema definition. It is a structured object with `name`, `description`, and a `fields` array where each field has `type` (string, integer, datetime, object, array, among others), `name`, and `description`. A flat object such as `{"title":"string"}` is rejected and the action fails.
- `instruction` (string, optional): additional parsing instructions. This is a sibling parameter of `parse_json`, not a field inside `data_schema`.
- `model` (string, optional): the parsing model. Defaults to `gpt-4o-mini`. Check the live docs for accepted values.
- `input_token_cap` (integer, optional): max source tokens. Default 1000000.
- `selector` (string, optional): CSS selector for a content subset.
- `output_type` (string, optional): one of `file`, `inline`. Default `file`.
- `max_pages` (integer, optional): PDF page limit. No default documented.

### parse_table
- `selector` (string, required): CSS selector identifying the table.
- `timeout` (integer, optional): max wait for the table. Default 5000 ms.

## Notes on parse_json

There is no free-form `prompt` parameter. Extraction is driven by `data_schema` or `data_schema_id`, with `instruction` as an optional refinement. Do not emit a `prompt` field for `parse_json`.

Verified behavior: running `parse_json` over the full DOM of a large, content-rich page (for example a Wikipedia article) returns `data.error: action_failed` with no `output`, even with a valid `data_schema`. Narrow the input to fix it: pass a `selector` for the region that holds the data (cheaper, around 2 credits in testing), or set `input_token_cap` (worked but cost more, around 4 credits). Small pages extract fine without either.

## When to use parse_json

`parse_json` is LLM-backed, so it is token-priced and its output can vary between runs. Weigh that against a deterministic path before reaching for it, and explain the trade-off to the developer so they can choose.

- Prefer a deterministic path when the value sits in a stable, well-structured place. A `selector` with a plain capture, `parse_table`, or a small parsing step in the target project's own language is cheaper, repeatable, and gives the same result every run. Good for a price in a known element, a field in a JSON blob, a table.
- Reach for `parse_json` when the value is embedded in free text or its location varies from page to page (for example a salary mentioned somewhere inside a job description), or when the task is interpretive rather than a lookup (summarising a page, classifying content). This is where the LLM earns its cost, because a selector cannot express it.
- It is the wrong tool when you need identical, reproducible output across runs. Use a deterministic path there instead.

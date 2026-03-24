# cmux Browser — Full Reference

## Core Workflow

1. Open or target a browser surface
2. Verify navigation with `get url` before waiting or snapshotting
3. Snapshot (`--interactive`) to get fresh element refs
4. Act with refs (`click`, `fill`, `type`, `select`, `press`)
5. Wait for state changes
6. Re-snapshot after DOM/navigation changes

```bash
cmux --json browser open https://example.com
# use returned surface ref, e.g. surface:7

cmux browser surface:7 get url
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive
cmux browser surface:7 fill e1 "hello"
cmux --json browser surface:7 click e2 --snapshot-after
```

## Surface Targeting

```bash
cmux browser open https://example.com --workspace workspace:2 --window window:1 --json
```

- CLI output defaults to short refs (`surface:N`, `pane:N`).
- Keep using one `surface:N` per task unless you intentionally switch.

## Navigation

```bash
cmux browser <surface> open <url>
cmux browser <surface> navigate <url>
cmux browser <surface> back / forward / reload
cmux browser <surface> url                        # get current URL
cmux browser <surface> get title
```

## Wait Patterns

```bash
cmux browser <surface> wait --selector "#ready" --timeout-ms 10000
cmux browser <surface> wait --text "Success" --timeout-ms 10000
cmux browser <surface> wait --url-contains "/dashboard" --timeout-ms 10000
cmux browser <surface> wait --load-state complete --timeout-ms 15000
cmux browser <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000
```

## DOM Inspection

```bash
cmux browser <surface> snapshot [--interactive] [--compact] [--max-depth <n>]
cmux browser <surface> get text|html|value <selector>
cmux browser <surface> get attr <selector> --attr <name>
cmux browser <surface> get count|box|styles <selector>
cmux browser <surface> is visible|enabled|checked <selector>
```

## Element Interaction

```bash
cmux browser <surface> click|dblclick|hover|focus <selector>
cmux browser <surface> scroll-into-view <selector>
cmux browser <surface> scroll [--dy <pixels>]
```

## Form Input

```bash
cmux browser <surface> type <selector> "text"     # append
cmux browser <surface> fill <selector> "text"     # clear + type
cmux browser <surface> fill <selector> ""         # clear input
cmux browser <surface> check|uncheck <selector>
cmux browser <surface> select <selector> "value"
cmux browser <surface> press <key>                # Enter, Tab, Escape, etc.
```

## Find Elements

```bash
cmux browser <surface> find role <role> [--name <name>]
cmux browser <surface> find text "text" [--exact]
cmux browser <surface> find label|placeholder "text"
cmux browser <surface> find testid "id"
cmux browser <surface> find first|nth <index> <selector>
```

## JavaScript & Screenshots

```bash
cmux browser <surface> eval "document.title"
cmux browser <surface> screenshot [--out <path>]
```

## Tabs, Cookies & Storage

```bash
cmux browser <surface> tab list|new [<url>]|switch|close
cmux browser <surface> cookies get|set|clear [...]
cmux browser <surface> storage local|session get|set|clear [...]
```

## Common Flows

### Form Submit

```bash
cmux --json browser open https://example.com/signup
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive
cmux browser surface:7 fill e1 "Jane Doe"
cmux browser surface:7 fill e2 "jane@example.com"
cmux --json browser surface:7 click e3 --snapshot-after
cmux browser surface:7 wait --url-contains "/welcome" --timeout-ms 15000
```

### Stable Agent Loop (recommended)

```bash
cmux browser surface:7 get url                    # verify navigation
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive     # get refs
cmux --json browser surface:7 click e5 --snapshot-after
cmux browser surface:7 snapshot --interactive     # refresh refs
```

If `get url` returns empty or `about:blank`, navigate first.

## WKWebView Limits

These return `not_supported`: viewport emulation, offline emulation, trace/screencast recording, network interception, raw input injection. Use high-level commands instead.

## Troubleshooting

### `js_error` on `snapshot --interactive` or `eval`

```bash
cmux browser surface:7 get url                    # verify page loaded
cmux browser surface:7 get text body              # fallback
cmux browser surface:7 get html body              # fallback
```

GitHub and other CSP-strict sites may block `eval`. Fall back to `get text body`.

# Browser fallback (read-only) & unknown forges

For reading a review the CLI/API can't reach: SSO-only instances, missing tokens,
or a forge these references don't cover (Gitea, Azure DevOps, Gerrit, …).

**Reading only.** Publishing stays in the forge's authenticated CLI/API. With no
usable CLI/API, the run is drafts-only / local-only: hand the user copy-paste-ready
replies or the review report — never click "Comment", "Resolve", or "Approve" in a
web UI. Button-clicking in the user's authenticated session is fragile, hard to
audit, and publishes under their name without a reliable record of what was sent.

**Tooling.** This fallback drives the Claude-in-Chrome MCP tools
(`mcp__claude-in-chrome__*`), which the plugin's commands allowlist. They exist
only when the Claude-in-Chrome extension is connected — if it isn't, there is no
browser path, so fall back to pasted comments or drafts-only / local-only output.

## Claude-in-Chrome flow

- `list_connected_browsers`. More than one connected → you **must** ask which one
  (AskUserQuestion), listing every browser by name + deviceId plus a final "let me
  pick in Chrome" option. Never auto-pick.
- The user's existing tab is not in the automatable tab group — `navigate` a
  **fresh** tab to the PR/MR URL. Same Chrome profile, so their login carries over;
  no need to log in.
- `get_page_text` usually captures the whole discussion in one shot. Expand
  collapsed threads / "Show resolved" / "Load more" by clicking first if the text
  comes back partial; `screenshot` only when text extraction still misses layout.
- Capture the same fields as the API path: reviewer, file:line, exact words,
  resolvable vs reply-only, thread state — and reconcile against the visible
  open-thread count so nothing is missed.

## Unknown forge checklist

1. Say plainly that this forge has no CLI/API coverage here — output will be
   drafts/local-only.
2. Read the discussion via the browser flow above (or pasted comments).
3. Confirm the source and target branch with the user (you may not be able to
   read them from the page reliably), then continue the skill's normal loop.
4. If this forge keeps coming up, suggest adding a reference file for it to the
   utopia-reviews plugin — the structure of github.md is the template.

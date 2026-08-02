# Bitbucket Cloud — reading and posting PR reviews

There is no official Bitbucket CLI — use `curl` against the REST 2.0 API. This
path is thinner and less battle-tested than GitHub/GitLab; verify responses as you
go, and fall back to the browser (read-only) or drafts when something is off.

Link shape: `https://bitbucket.org/<workspace>/<repo-slug>/pull-requests/<id>`.

## Auth

App password (or workspace API token) supplied by the user — typically as env vars:

```bash
# expected in the environment; NEVER echo or log their values
: "${BITBUCKET_USERNAME:?}" "${BITBUCKET_APP_PASSWORD:?}"
BB="https://api.bitbucket.org/2.0/repositories/<workspace>/<repo-slug>"
auth() { curl -sS -u "$BITBUCKET_USERNAME:$BITBUCKET_APP_PASSWORD" "$@"; }
```

No credentials → reading via browser fallback, output as drafts. Ask the user
where their token lives; don't hunt for it.

## PR metadata & branches

```bash
auth "$BB/pullrequests/<id>" | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(d['title'], '|', d['source']['branch']['name'], '->', d['destination']['branch']['name'], '|', d['state'])"
# source.branch.name = reviewed branch · destination.branch.name = merge target
```

Checkout: Bitbucket Cloud exposes no PR refs — fetch the source branch directly
(`git fetch origin <source-branch> && git checkout <source-branch>`). Fork PRs need
the fork added as a remote first; ask the user rather than guessing the fork URL.

## Reading comments

```bash
auth "$BB/pullrequests/<id>/comments?pagelen=100"
# paginate: follow the top-level "next" URL until absent
```

- Inline comments carry `inline.path` and `inline.to` (line on the new side);
  comments without `inline` are general PR comments.
- Threads are linked by `parent.id`; a comment with `deleted: true` is gone.
- `resolution` present on a comment means its thread is resolved — skip those.

## Replying to a comment thread

```bash
auth -X POST "$BB/pullrequests/<id>/comments" \
  -H 'Content-Type: application/json' \
  -d '{"content": {"raw": "<reply text>"}, "parent": {"id": <comment-id>}}'
```

## Resolving a thread

Only for threads whose fix is committed AND pushed:

```bash
auth -X POST "$BB/pullrequests/<id>/comments/<comment-id>/resolve"
```

(Resolve targets the thread's root comment id. A 404 here can mean an unknown
comment id, an id that is a reply rather than the thread root, or an older
workspace that lacks this endpoint - in any case, say so in the report and leave
resolution to the user.)

## Posting a review

No batched-review object — post the summary as a general comment, then one inline
comment per finding, in finding order:

```bash
# Summary
auth -X POST "$BB/pullrequests/<id>/comments" \
  -H 'Content-Type: application/json' \
  -d '{"content": {"raw": "## Review: feature/x → main\nVerdict: ship after fixes\n…"}}'

# Inline finding
auth -X POST "$BB/pullrequests/<id>/comments" \
  -H 'Content-Type: application/json' \
  -d '{"content": {"raw": "1. `useSubmitState` swallows the error here — rethrow or surface it."},
       "inline": {"path": "lib/screen/main_screen.dart", "to": 42}}'
```

Approve (`auth -X POST "$BB/pullrequests/<id>/approve"`) only when the user
explicitly says so.

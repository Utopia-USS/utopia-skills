# GitHub — reading and posting PR reviews

All commands assume `gh` is authenticated (`gh auth status`) and run from the repo
checkout. GraphQL is the only GitHub API that groups review comments into threads
and exposes resolution — prefer it over REST.

Link shape: `https://github.com/<owner>/<repo>/pull/<number>`.

## Contents

- [PR metadata, branches & CI](#pr-metadata-branches--ci)
- [Review threads (GraphQL)](#review-threads-graphql)
- [Review bodies & issue comments](#review-bodies--issue-comments)
- [Replying to a thread](#replying-to-a-thread)
- [Resolving a thread](#resolving-a-thread)
- [Posting a review with inline comments](#posting-a-review-with-inline-comments)
- [REST fallbacks](#rest-fallbacks)

## PR metadata, branches & CI

```bash
gh pr view <url-or-number> --json number,title,body,author,headRefName,headRefOid,baseRefName,isDraft,reviewDecision,url
# headRefName = source (reviewed) branch · baseRefName = target branch
gh pr checks <url-or-number>          # CI status; failing checks belong in the plan
gh pr checkout <number>               # handles fork remotes; requires a clean tree
gh pr list --head <branch> --json number,url,baseRefName   # find an open PR for a branch
```

## Review threads (GraphQL)

The one query that matters — threads with ids, resolution state, and all comments:

```bash
gh api graphql -f owner='<owner>' -f repo='<repo>' -F pr=<number> -f query='
query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 50) {
            nodes {
              databaseId
              author { login }
              body
              diffHunk
              createdAt
              url
            }
          }
        }
      }
    }
  }
}'
```

- Paginate: while `pageInfo.hasNextPage`, re-run with `-f cursor=<endCursor>`.
- `id` is the thread id used by the reply and resolve mutations below.
- Skip `isResolved: true`. Keep `isOutdated: true` — the code moved, but nobody
  confirmed the concern is addressed.
- The last comment's author tells you whether the thread already has an answer.

## Review bodies & issue comments

Reply-only surfaces (no resolve button), still part of "every comment":

```bash
gh pr view <number> --json reviews \
  --jq '.reviews[] | select(.body != "") | {author: .author.login, state, body}'
gh pr view <number> --json comments \
  --jq '.comments[] | {author: .author.login, body, url}'
```

Respond to these with a top-level comment when needed:

```bash
gh pr comment <number> --body '<text>'
```

## Replying to a thread

```bash
gh api graphql -f threadId='<thread-id>' -f body='<reply text>' -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(
    input: { pullRequestReviewThreadId: $threadId, body: $body }
  ) {
    comment { url }
  }
}'
```

Post the approved text verbatim — the gate already fixed the wording.

## Resolving a thread

Only for threads whose fix is committed AND pushed. Never for pushback replies.

```bash
gh api graphql -f threadId='<thread-id>' -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread { id isResolved }
  }
}'
```

## Posting a review with inline comments

One batched review — summary in the body, findings as inline comments. Build the
JSON in a file to keep quoting sane:

```bash
cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "body": "## Review: feature/x → main\nVerdict: ship after fixes\n…",
  "comments": [
    { "path": "lib/screen/main_screen.dart", "line": 42, "side": "RIGHT",
      "body": "1. `useSubmitState` swallows the error here — rethrow or surface it in the view." },
    { "path": "lib/state/foo_state.dart", "start_line": 10, "line": 14, "side": "RIGHT",
      "body": "2. This block re-creates the controller on every build — hoist it into the hook." }
  ]
}
EOF
gh api -X POST "repos/<owner>/<repo>/pulls/<number>/reviews" --input /tmp/review.json
```

- `line` anchors to the NEW side of the diff (`side: RIGHT`); multi-line comments
  add `start_line`. Anchors must lie inside the PR diff — a comment on an untouched
  line is rejected; put such remarks in the review body instead.
- `event` stays `COMMENT` unless the user explicitly asked to approve
  (`APPROVE`) or request changes (`REQUEST_CHANGES`).
- Body-only review (no inline anchors): `gh pr review <number> --comment --body '<text>'`.

## REST fallbacks

When GraphQL is unavailable (rare — e.g. a token without GraphQL scope):

```bash
# Flat list of review comments; group into threads via in_reply_to_id
gh api "repos/<owner>/<repo>/pulls/<number>/comments" --paginate

# Reply to a thread by its FIRST comment's numeric id (databaseId)
gh api -X POST "repos/<owner>/<repo>/pulls/<number>/comments/<comment-id>/replies" \
  -f body='<reply text>'
```

There is no REST endpoint for resolving threads — resolution is GraphQL-only. If
only REST works, reply but leave resolution to the user, and say so in the report.

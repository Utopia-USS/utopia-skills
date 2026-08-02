# GitLab — reading and posting MR reviews

All commands assume `glab` is authenticated (`glab auth status`) and run from the
repo checkout — the `:id` placeholder then resolves to the current project. For
self-hosted instances, `glab` must be logged into that hostname.

Link shape: `https://gitlab.com/<group>/<project>/-/merge_requests/<iid>` (the
number in the URL is the MR **iid**).

## Contents

- [MR metadata, branches & CI](#mr-metadata-branches--ci)
- [Reading discussions](#reading-discussions)
- [Replying to a discussion](#replying-to-a-discussion)
- [Resolving a discussion](#resolving-a-discussion)
- [Posting a review](#posting-a-review)

## MR metadata, branches & CI

```bash
glab api "projects/:id/merge_requests/<iid>" \
  --jq '{title, description, author: .author.username,
         source_branch, target_branch, state, diff_refs}'
# source_branch = reviewed branch · target_branch = merge target
# diff_refs {base_sha, head_sha, start_sha} — needed for positioned comments below

glab ci status --branch <source-branch>       # pipeline state
glab mr checkout <iid>                        # clean tree required
glab mr list --source-branch=<branch>         # find an open MR for a branch
```

## Reading discussions

```bash
glab api "projects/:id/merge_requests/<iid>/discussions" --paginate
```

- Each discussion has `id` and `notes[]`. `individual_note: true` means a plain
  comment (reply-only surface); positioned notes carry
  `position.new_path` / `position.new_line` for file:line.
- A note with `resolvable: true, resolved: true` is done — skip it. Unresolved
  resolvable discussions are the work list.
- The MR description and pipeline comments are separate surfaces; read
  `glab mr view <iid>` for the overview.

## Replying to a discussion

```bash
glab api -X POST \
  "projects/:id/merge_requests/<iid>/discussions/<discussion-id>/notes" \
  -f body='<reply text>'
```

## Resolving a discussion

Only for discussions whose fix is committed AND pushed:

```bash
glab api -X PUT \
  "projects/:id/merge_requests/<iid>/discussions/<discussion-id>" \
  -F resolved=true
```

## Posting a review

GitLab has no batched-review object — post the summary as one note, findings as
positioned discussions (they land in "Changes" at file:line and are resolvable):

```bash
# 1. Summary note
glab mr note <iid> -m '## Review: feature/x → main
Verdict: ship after fixes
…'

# 2. One positioned discussion per finding (shas from diff_refs above)
glab api -X POST "projects/:id/merge_requests/<iid>/discussions" \
  -f body='1. `useSubmitState` swallows the error here — rethrow or surface it.' \
  -f 'position[position_type]=text' \
  -f 'position[base_sha]=<diff_refs.base_sha>' \
  -f 'position[head_sha]=<diff_refs.head_sha>' \
  -f 'position[start_sha]=<diff_refs.start_sha>' \
  -f 'position[new_path]=lib/screen/main_screen.dart' \
  -F 'position[new_line]=42'
```

- `new_path`/`new_line` must point into the MR diff; remarks about untouched code
  go into the summary note instead.
- Approve (`glab mr approve <iid>`) only when the user explicitly says so — the
  verdict is theirs, not yours.

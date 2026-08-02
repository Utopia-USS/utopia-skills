---
description: Review a changeset — PR/MR link or local branches — Utopia-aware, severity-ranked; can post inline comments after approval
argument-hint: "[PR/MR link | <source> [<target>]] [spec link or notes] [auto | local only]"
allowed-tools: Skill, Read, Bash, Glob, Grep, Agent, WebFetch, AskUserQuestion, TodoWrite, mcp__claude-in-chrome
model: inherit
---

# Utopia Code Review

Invoke the `utopia-code-review` skill (Skill tool) and follow it end to end.

Raw arguments: `$ARGUMENTS`

- The first URL is the PR/MR link; bare branch name(s) are the source (and target)
  branches; any other URL or free text is the optional task spec; the words "auto" /
  "local only" ("tylko lokalnie") select the mode.
- No arguments at all → review the current branch against the repo's default branch,
  per the skill's scope-resolution rules — don't ask first, just state the scope.

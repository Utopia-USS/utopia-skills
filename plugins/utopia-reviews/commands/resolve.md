---
description: Resolve review comments on a PR/MR — read, triage, one approval gate, then fix, push, and reply
argument-hint: "<PR link> [spec link or notes] [auto | drafts only]"
allowed-tools: Skill, Read, Edit, Bash, Glob, Grep, Agent, WebFetch, AskUserQuestion, TodoWrite, mcp__claude-in-chrome
model: inherit
---

# Resolve Code Review

Invoke the `utopia-resolve-code-review` skill (Skill tool) and follow it end to end.

Raw arguments: `$ARGUMENTS`

- Treat the first URL as the PR/MR link; any other URL or free text is the optional
  task spec; the words "auto" / "drafts only" ("tylko drafty") select the mode.
- If `$ARGUMENTS` is empty and no PR link appears earlier in the conversation, ask
  using the skill's input template — one question, then wait.

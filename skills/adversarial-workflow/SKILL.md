---
name: adversarial-workflow
description: >
  This skill should be used when the user asks about "adversarial review",
  "codex review loop", "plan review with codex", "dual-agent review",
  or discusses using multiple AI agents for code review.
---

# Adversarial Review Workflow

This project has an adversarial review plugin that orchestrates iterative review loops between Claude Code and OpenAI Codex CLI.

## Available Commands

### `/adversarial-plan <task description>`
Creates an implementation plan with adversarial review:
1. Claude analyzes the codebase and writes a detailed implementation plan
2. Codex reviews the plan critically as a senior staff engineer
3. Claude revises based on feedback
4. Loop continues until Codex approves or max iterations (20) reached
5. **Pauses for user approval** before any implementation

### `/adversarial-review`
Runs adversarial code review on current changes:
1. Captures git diff of all changes
2. Codex reviews the code for bugs, security issues, performance, and style
3. Claude autonomously fixes any critical issues found
4. Loop continues until Codex approves or max iterations (20) reached
5. No pause — fixes are applied automatically

## Convergence Protocol

Codex ends every review with exactly one of:
- **`APPROVED`** — no blocking issues, work is acceptable
- **`NEEDS_REVISION`** — blocking issues listed that must be addressed

Convergence typically happens in 2-3 iterations. The 20-iteration limit is a safety backstop.

## Artifact Storage

All artifacts are saved to `.adversarial-review/<session-slug>/` in the project root. Each run of `/adversarial-plan` or `/adversarial-review` creates a new session directory with a unique slug, so previous sessions are preserved.

A `latest` symlink at `.adversarial-review/latest` always points to the most recent session. This is used by `/adversarial-review` to find `plan_final.md` from a prior planning session.

```
.adversarial-review/
  latest -> abcd-efgh-ijkl/
  abcd-efgh-ijkl/           # planning session
    plan_v1.md, plan_v2.md, ...
    review_v1.md, review_v2.md, ...
    plan_final.md
  mnop-qrst-uvwx/           # code review session
    diff_for_review.md
    code_review_v1.md, code_review_v2.md, ...
```

You may want to add `.adversarial-review/` to your project's `.gitignore`.

## Customization

Plugin files are installed to the Claude Code plugin cache. To customize, fork the repo and point your marketplace at your fork, or edit files in the cache directly (changes will be overwritten on update).

- **Iteration limit**: Currently hardcoded to 20 in the command files (`commands/adversarial-plan.md`, `commands/adversarial-review.md`)
- **Review prompts**: Customize what Codex evaluates by editing `scripts/codex-review.sh`
- **Review types**: The script supports `plan` (architectural review) and `code` (code change review) types

# Adversarial Review

A Claude Code plugin that orchestrates adversarial review loops between **Claude Code** and **OpenAI Codex CLI**. Claude writes plans and code; Codex tears them apart. They iterate until convergence.

## How It Works

This plugin adds two slash commands to Claude Code:

### `/adversarial-plan <task description>`

Pre-implementation planning with adversarial critique.

1. Claude analyzes your codebase and writes a detailed implementation plan
2. Codex reviews the plan as a pragmatic senior engineer — looking for real bugs, not theoretical nitpicks
3. Claude revises based on feedback
4. Loop continues until Codex approves (or 20 iterations max)
5. Pauses for your approval before any code is written

### `/adversarial-review`

Post-implementation code review on your current git changes.

1. Captures your git diff
2. Codex reviews for bugs, security issues, and correctness problems
3. Claude autonomously fixes any critical issues found
4. Loop continues until Codex approves (or 20 iterations max)

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and configured
- [OpenAI Codex CLI](https://github.com/openai/codex) installed and on your PATH (`codex exec` must work)

## Installation

Clone this repository into your Claude Code plugins directory:

```bash
git clone git@github.com:bobby-beckmann/adversarial-review.git ~/.claude/plugins/adversarial-review
```

Then restart Claude Code (or run `/reload-plugins` if available). The `/adversarial-plan` and `/adversarial-review` commands will be available in all projects.

## Convergence Protocol

Codex ends every review with one of:

- **`APPROVED`** — no blocking issues, work is acceptable
- **`NEEDS_REVISION`** — blocking issues that must be addressed

Reviews are calibrated to be pragmatic. A simple script doesn't get the same scrutiny as a payment system. Convergence typically happens in 2-3 iterations.

## Artifacts

Each run creates a unique session directory under `.adversarial-review/` in your project root:

```
.adversarial-review/
  latest -> abcd-efgh-ijkl/       # symlink to most recent session
  abcd-efgh-ijkl/
    plan_v1.md, plan_v2.md, ...   # plan iterations
    review_v1.md, review_v2.md, ... # Codex reviews of each plan
    plan_final.md                  # converged final plan
  mnop-qrst-uvwx/
    diff_for_review.md             # code changes sent for review
    code_review_v1.md, ...         # Codex code review rounds
```

Previous sessions are preserved. You may want to add `.adversarial-review/` to your `.gitignore`.

## Customization

- **Iteration limit**: Edit the commands in `commands/` to change from the default 20
- **Review prompts**: Customize what Codex evaluates by editing `scripts/codex-review.sh`
- **Review stance**: The prompts are tuned for pragmatic review — modify them if you want stricter or more lenient feedback

## License

MIT

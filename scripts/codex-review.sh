#!/usr/bin/env bash
set -euo pipefail

# codex-review.sh — Wrapper to invoke codex exec for adversarial review
#
# Usage: codex-review.sh <input-file> <output-file> <review-type> <project-dir> [previous-review-file]
#   input-file            — path to the file to review (plan or diff)
#   output-file           — path where review output will be written
#   review-type           — "plan" or "code"
#   project-dir           — project root directory for context
#   previous-review-file  — (optional) path to your previous review, for continuity

if ! command -v codex &>/dev/null; then
  echo "Error: OpenAI Codex CLI is not installed or not on PATH." >&2
  echo "Install it from: https://github.com/openai/codex" >&2
  exit 1
fi

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <input-file> <output-file> <review-type> <project-dir> [previous-review-file]" >&2
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
REVIEW_TYPE="$3"
PROJECT_DIR="$4"
PREV_REVIEW_FILE="${5:-}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: Input file not found: $INPUT_FILE" >&2
  exit 1
fi

INPUT_CONTENT="$(cat "$INPUT_FILE")"

# Build previous review context if provided
PREV_REVIEW_SECTION=""
if [[ -n "$PREV_REVIEW_FILE" && -f "$PREV_REVIEW_FILE" ]]; then
  PREV_REVIEW_CONTENT="$(cat "$PREV_REVIEW_FILE")"
  PREV_REVIEW_SECTION="
---

YOUR PREVIOUS REVIEW (for context):
You already reviewed an earlier version and gave this feedback. The author has revised based on your input. Focus on whether your previous concerns were addressed. Do not introduce new blocking issues unless they are genuinely critical — avoid escalating scope or complexity beyond what you originally asked for.

$PREV_REVIEW_CONTENT

---
"
fi

if [[ "$REVIEW_TYPE" == "plan" ]]; then
  REVIEW_PROMPT="You are a pragmatic senior engineer reviewing an implementation plan. Your goal is to ensure the plan is sound and will work correctly — not to find every theoretical edge case.

**Calibrate your review to the scope and complexity of the task.** A simple CLI tool does not need the same rigor as a distributed payment system. Only flag issues that would actually cause problems in realistic usage of this specific tool.

Review the plan for:
- **Correctness**: Will this approach actually work for its intended use case?
- **Feasibility**: Can this realistically be implemented as described?
- **Obvious gaps**: Are there important things clearly missing?
- **Over-engineering**: Is the plan more complex than necessary for the stated goal?

IMPORTANT guidelines for your verdict:
- A plan does NOT need to handle every theoretical edge case to be APPROVED
- A plan does NOT need to be perfect to be APPROVED — it needs to be good enough to implement successfully
- Only mark as NEEDS_REVISION if there are issues that would cause the implementation to **fail or be fundamentally wrong**
- Prefer APPROVED with suggestions over NEEDS_REVISION for minor improvements
- If the plan is reasonable and would produce working software, APPROVE it
- If this is a follow-up review: focus on whether your previous concerns were adequately addressed. Do NOT raise new blocking issues unless they are serious enough that you would have flagged them in the first review
${PREV_REVIEW_SECTION}
Provide your review in this exact format:

## Critical Issues (Blocking)
List only issues that would cause the implementation to fail or be fundamentally broken. If none, write \"None.\"

## Suggestions (Non-blocking)
List improvements that would be nice but aren't required. If none, write \"None.\"

## What's Good
Briefly note what's well done in this plan.

## Verdict
End with EXACTLY one of these words on its own line:
APPROVED
or
NEEDS_REVISION

---

PLAN TO REVIEW:

$INPUT_CONTENT"

elif [[ "$REVIEW_TYPE" == "code" ]]; then
  REVIEW_PROMPT="You are a pragmatic senior engineer reviewing code changes. Your goal is to catch real bugs and security issues — not to nitpick style or find theoretical problems.

**Calibrate your review to the scope of the changes.** Only flag issues that would actually cause bugs, security vulnerabilities, or serious problems in practice.

Review the code for:
- **Bugs**: Real logic errors that will cause incorrect behavior
- **Security**: Actual vulnerabilities (injection, auth bypass, secrets exposure) — not theoretical concerns
- **Correctness**: Does the code do what it's supposed to do?

IMPORTANT guidelines for your verdict:
- Code does NOT need to be perfect to be APPROVED — it needs to work correctly and safely
- Only mark as NEEDS_REVISION if there are bugs that will cause incorrect behavior or real security vulnerabilities
- Style preferences, minor improvements, and theoretical edge cases are SUGGESTIONS, not blocking issues
- If the code works correctly for its intended purpose, APPROVE it
- If this is a follow-up review: focus on whether your previous concerns were adequately addressed. Do NOT raise new blocking issues unless they are serious enough that you would have flagged them in the first review
${PREV_REVIEW_SECTION}
Provide your review in this exact format:

## Critical Issues (Blocking)
List only real bugs or security vulnerabilities that need fixing. If none, write \"None.\"

## Suggestions (Non-blocking)
List improvements that would be nice but aren't required. If none, write \"None.\"

## What's Good
Briefly note what's well done in these changes.

## Verdict
End with EXACTLY one of these words on its own line:
APPROVED
or
NEEDS_REVISION

---

CODE CHANGES TO REVIEW:

$INPUT_CONTENT"

else
  echo "Error: review-type must be 'plan' or 'code', got: $REVIEW_TYPE" >&2
  exit 1
fi

cd "$PROJECT_DIR"

codex exec --full-auto -o "$OUTPUT_FILE" "$REVIEW_PROMPT"

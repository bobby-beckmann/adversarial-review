---
name: adversarial-review
description: Run adversarial code review by Codex on current changes. Codex reviews the diff, Claude fixes issues autonomously, iterating until convergence.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent
user-invocable: true
---

# Adversarial Code Review Command

You are orchestrating an adversarial code review workflow. OpenAI Codex CLI reviews the current code changes, and Claude (you) autonomously fixes any issues found. You iterate until Codex approves or you hit the max iteration limit.

## Instructions

The user has invoked `/adversarial-review`. Follow these steps exactly:

### Step 1: Setup

Generate a unique session slug and create the session directory. Use the Bash tool to run:

```
SLUG=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z' | fold -w 4 | head -n 3 | tr '\n' '-' | sed 's/-$//'); SESSION_DIR=".adversarial-review/$SLUG"; mkdir -p "$SESSION_DIR"; ln -sfn "$SLUG" .adversarial-review/latest; echo "$SESSION_DIR"
```

**IMPORTANT:** The output of this command is the session directory path (e.g., `.adversarial-review/abcd-efgh-ijkl`). Use this exact path as `$SESSION_DIR` in ALL subsequent steps. Every file you read or write in this workflow goes inside this directory.

### Step 2: Gather Context

1. **Read the plan** (if it exists) for implementation context:
   Use the Read tool on `.adversarial-review/latest/plan_final.md` if it exists. This provides context about the intent behind the changes. Note: the `latest` symlink may point to a previous planning session.

2. **Capture current changes.** Use the Bash tool to run:

   ```
   git diff HEAD > $SESSION_DIR/diff_for_review.md 2>/dev/null; git diff --cached >> $SESSION_DIR/diff_for_review.md 2>/dev/null; if [ ! -s $SESSION_DIR/diff_for_review.md ]; then git diff main...HEAD > $SESSION_DIR/diff_for_review.md 2>/dev/null || git diff origin/main...HEAD > $SESSION_DIR/diff_for_review.md 2>/dev/null || echo "No changes detected" > $SESSION_DIR/diff_for_review.md; fi
   ```

   If the diff is empty or says "No changes detected", inform the user and stop.

### Step 3: Review Loop

Starting at iteration 1, loop up to **20 iterations**. For each iteration N (starting at 1):

1. **Send changes for Codex review.** Use the Bash tool to run the codex-review script, substituting the actual iteration number for N. On iteration 2+, pass the previous review file as the 5th argument so Codex has context on what it already asked for:

   Iteration 1:
   ```
   bash ~/.claude/plugins/adversarial-review/scripts/codex-review.sh $SESSION_DIR/diff_for_review.md $SESSION_DIR/code_review_v1.md code "$(pwd)"
   ```

   Iteration 2+:
   ```
   bash ~/.claude/plugins/adversarial-review/scripts/codex-review.sh $SESSION_DIR/diff_for_review.md $SESSION_DIR/code_review_v2.md code "$(pwd)" $SESSION_DIR/code_review_v1.md
   ```

   Always pass the previous iteration's review file (code_review_v{N-1}.md) as the last argument on follow-up iterations.

2. **Read the review.** Use the Read tool to read `$SESSION_DIR/code_review_vN.md` (using the actual number).

3. **Check verdict:**
   - If the review contains `APPROVED`:
     - Break out of the loop — code review is complete
   - If the review contains `NEEDS_REVISION`:
     - Read all critical issues carefully
     - **Autonomously apply fixes** to the codebase to address ALL critical (blocking) issues
     - Apply reasonable non-blocking suggestions where appropriate
     - After making fixes, re-capture the updated diff using the Bash tool:

       ```
       git diff HEAD > $SESSION_DIR/diff_for_review.md 2>/dev/null; git diff --cached >> $SESSION_DIR/diff_for_review.md 2>/dev/null; if [ ! -s $SESSION_DIR/diff_for_review.md ]; then git diff main...HEAD > $SESSION_DIR/diff_for_review.md 2>/dev/null || git diff origin/main...HEAD > $SESSION_DIR/diff_for_review.md 2>/dev/null || echo "No changes detected" > $SESSION_DIR/diff_for_review.md; fi
       ```

     - Continue the loop with the next iteration number
   - If neither marker is found:
     - Treat as `NEEDS_REVISION` and note the parsing issue

4. **If max iterations (20) reached:**
   - Note that the review did not fully converge
   - Continue to the summary step

### Step 4: Present Summary

Display to the user:
- How many review iterations occurred
- A summary of each round's findings and what was fixed
- Whether the review converged (APPROVED) or hit the iteration limit
- List of all files modified during the review process

Tell the user:

> The adversarial code review is complete. All artifacts are saved in `$SESSION_DIR/`.
>
> You can review the individual round feedback in `$SESSION_DIR/code_review_v*.md` files.

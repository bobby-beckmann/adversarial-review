---
name: adversarial-plan
description: Create an implementation plan with adversarial review by Codex. Claude writes the plan, Codex reviews it, and they iterate until convergence.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent
user-invocable: true
---

# Adversarial Plan Command

You are orchestrating an adversarial planning workflow. Claude (you) creates implementation plans, and OpenAI Codex CLI reviews them critically. You iterate until Codex approves or you hit the max iteration limit. Use ultrathink for deep analysis throughout this workflow.

## Instructions

The user has invoked `/adversarial-plan` with a task description. Follow these steps exactly:

### Step 1: Setup

Generate a unique session slug and create the session directory. Use the Bash tool to run:

```
SLUG=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z' | fold -w 4 | head -n 3 | tr '\n' '-' | sed 's/-$//'); SESSION_DIR=".adversarial-review/$SLUG"; mkdir -p "$SESSION_DIR"; ln -sfn "$SLUG" .adversarial-review/latest; echo "$SESSION_DIR"
```

**IMPORTANT:** The output of this command is the session directory path (e.g., `.adversarial-review/abcd-efgh-ijkl`). Use this exact path as `$SESSION_DIR` in ALL subsequent steps. Every file you read or write in this workflow goes inside this directory.

### Step 2: Analyze Codebase

Examine the project structure and relevant code to understand the context for planning. Use Glob, Grep, Read, and Agent tools as needed to gather sufficient understanding.

### Step 3: Write Initial Plan

Write a detailed implementation plan to `$SESSION_DIR/plan_v1.md`. The plan should include:
- **Goal**: What we're building and why
- **Approach**: High-level architecture and design decisions
- **Implementation Steps**: Ordered, detailed steps with file paths and code patterns
- **Edge Cases**: Only edge cases that are realistic for the stated use case
- **Testing Strategy**: How to verify the implementation works
- **Dependencies**: Any new packages, services, or tools needed

**IMPORTANT: Keep the plan proportional to the task complexity.** A simple script does not need enterprise-grade error handling. Do not over-engineer. When the reviewer suggests handling extreme edge cases that are unlikely in practice, push back or acknowledge them as out-of-scope rather than adding complexity. The goal is a working solution, not a theoretically perfect one.

### Step 4: Review Loop

Starting at iteration 1, loop up to **20 iterations**. For each iteration N (starting at 1):

1. **Send plan for Codex review.** Use the Bash tool to run the codex-review script, substituting the actual iteration number for N. On iteration 2+, pass the previous review file as the 5th argument so Codex has context on what it already asked for:

   Iteration 1:
   ```
   bash ~/.claude/plugins/adversarial-review/scripts/codex-review.sh $SESSION_DIR/plan_v1.md $SESSION_DIR/review_v1.md plan "$(pwd)"
   ```

   Iteration 2+:
   ```
   bash ~/.claude/plugins/adversarial-review/scripts/codex-review.sh $SESSION_DIR/plan_v2.md $SESSION_DIR/review_v2.md plan "$(pwd)" $SESSION_DIR/review_v1.md
   ```

   Always pass the previous iteration's review file (review_v{N-1}.md) as the last argument on follow-up iterations.

2. **Read the review.** Use the Read tool to read `$SESSION_DIR/review_vN.md` (using the actual number).

3. **Check verdict:**
   - If the review contains `APPROVED`:
     - Copy the current plan to `$SESSION_DIR/plan_final.md`
     - Break out of the loop
   - If the review contains `NEEDS_REVISION`:
     - Carefully read all critical issues and suggestions
     - Address critical issues that represent real, practical problems. If a critical issue is theoretical or disproportionate to the task scope, acknowledge it and explain why it's out of scope rather than adding complexity. Do NOT blindly add complexity to satisfy every concern — resist over-engineering and hold firm on simplicity when appropriate
     - Save the revised plan as `$SESSION_DIR/plan_v{N+1}.md` (e.g., if N=1, save as plan_v2.md)
     - Continue the loop with the next iteration number
   - If neither marker is found:
     - Treat as `NEEDS_REVISION` and note the parsing issue

4. **If max iterations (20) reached:**
   - Save the current plan as `$SESSION_DIR/plan_final.md`
   - Add a note at the top: `> Warning: Plan did not fully converge after 20 iterations. Review carefully.`

### Step 5: Present Results

Display to the user:
- The final plan content
- How many iterations it took to converge (or that it didn't converge)
- A brief summary of what changed between the first and final versions

### Step 6: STOP

**IMPORTANT: Do NOT proceed to implementation.** Tell the user:

> The adversarial plan review is complete. The plan has been saved to `$SESSION_DIR/plan_final.md`.
>
> When you're ready to implement, you can ask me to proceed. After implementation, use `/adversarial-review` to have Codex review the code changes.

Wait for the user to explicitly approve before taking any implementation action.

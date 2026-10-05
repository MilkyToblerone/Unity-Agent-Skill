---
name: where-am-i
description: Summarize project status — what's built, what's in progress, what's next, gate state, and what changed recently. Use when the user asks "where am I", "status", or "what's next".
---

Give the user a status summary, under 25 lines:

1. **Gate:** read `.claude/state/gate.json` — status, step, changed files. Translate it: `open` = free to start a step; `dirty` = changes not reviewed yet; `pending` = review done, waiting for the user (approve / quiz / rework / arch-fix).
2. **Roadmap:** from `docs/ROADMAP.md` — steps done, current step, next 2 steps.
3. **Recent changes:** `git log --oneline -10` and `git status --short`. Point out uncommitted work, and new scripts whose `.meta` isn't staged.
4. **Last review:** newest file in `docs/reviews/` — verdict, open drift items, quiz result.
5. **Learning:** if `.claude/agent-memory/unity-architect/MEMORY.md` has a learning profile, one line on concepts to revisit.
6. **Suggested next action** — one line.

---
name: next-step
description: Start the next ROADMAP step under the unity-lead workflow (plan first, nothing coded until the user approves the plan).
disable-model-invocation: true
argument-hint: "[step id, optional]"
---

Start the next ROADMAP step.

1. Load the `unity-lead` skill if it isn't loaded, and follow it.
2. Read `.claude/state/gate.json`. If `status` isn't `open`, stop: tell the user which step is still waiting and what they can type (`approve`, quiz answers, `rework`, `arch-fix`, `skip-review`).
3. Pick the step: $ARGUMENTS if given, otherwise the first unchecked step in `docs/ROADMAP.md`. Read its "done when".
4. Read the ARCHITECTURE.md sections for every system the step touches.
5. Post the plan (unity-lead section 1.1) with your questions about anything the docs don't decide. Don't edit anything until the user approves the plan.

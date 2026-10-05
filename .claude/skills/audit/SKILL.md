---
name: audit
description: Run a full read-only architecture drift audit of the codebase with the unity-architect agent.
disable-model-invocation: true
argument-hint: "[system or folder, optional]"
---

Delegate to the **unity-architect** subagent in AUDIT mode. Scope: $ARGUMENTS (if empty: all of `Assets/`).

When it returns, show the user the audit as written, then the list of drift items with their options (rework / arch-fix / arch-update). Don't fix anything. Remind the user that drift fixes run as normal steps through the review gate.

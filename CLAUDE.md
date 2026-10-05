# CLAUDE.md

Unity 6 project, C#. The user is the **lead developer**. Agents work for them and must keep them in control of — and able to explain — every line of the codebase.

- For any code work (features, fixes, refactors, tests) use the **`unity-lead`** skill and follow it for the whole session.
- Source of truth, in read order: `docs/AGENT_GUIDE.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`. Agents move only according to these. If they look wrong or outdated, tell the user; don't work around them.
- Every finished ROADMAP step is reviewed by the **`unity-architect`** subagent before anything else happens. A review gate (`.claude/state/gate.json`, enforced by hooks) locks code edits until the user approves or passes the quiz.
- Gate words only the user can type: `approve`, `rework`, `arch-fix`, `arch-update`, `skip-review`.
- Agents never edit scenes, prefabs, assets, `.meta`, `ProjectSettings/` — they give the user Editor steps. The user handles git.
- Language: English for code, comments, reports and explanations.
- Commands: `/next-step`, `/explain <thing>`, `/where-am-i`, `/audit`.

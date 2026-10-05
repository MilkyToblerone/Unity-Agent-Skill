# Unity Lead Kit

A Claude Code setup for building a Unity 6 game with agents **while you stay the lead of your codebase**. Agents plan, ask, and code. An architect agent reviews every step, explains it to you, and quizzes you. Nothing moves forward until you approve or prove you understood it.

## What's in the box

| Path | What it is |
|---|---|
| `CLAUDE.md` | Always-loaded project rules (short) |
| `.claude/skills/unity-lead/` | The workflow skill: step loop, asking rules, Unity rules, debug protocol, report format |
| `.claude/agents/unity-architect.md` | The reviewer/teacher subagent (Opus, read-only unless you say `arch-fix` / `arch-update`) |
| `.claude/skills/next-step`, `explain`, `where-am-i`, `audit` | Your commands: `/next-step`, `/explain`, `/where-am-i`, `/audit` |
| `.claude/hooks/gate.ps1` + `.claude/settings.json` | The review gate — enforced by hooks, not just instructions |
| `docs/reviews/` | Every step report and quiz result lands here |

## Setup (Windows, once per project)

1. **Copy** `CLAUDE.md`, `.claude/` and `docs/` into your Unity project root (next to `Assets/`). Append `.gitignore-additions` to your `.gitignore`.
2. **Architecture docs:** run the architecture prompt and save its output as `docs/AGENT_GUIDE.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`.
3. **Unity bridge** (lets agents read the Console, recompile and run tests). In PowerShell:
   ```powershell
   winget install Unity.CLI
   cd C:\path\to\YourProject
   unity pipeline install
   unity mcp configure claude
   ```
   Open the project in Unity 6. Then in Claude Code run `/mcp` and check the Unity server is connected **and its name contains "unity"** — the gate's read-only filter keys on that. The Unity CLI is labeled experimental; if it misbehaves, the community package [MCP for Unity](https://github.com/CoplayDev/unity-mcp) works with the same gate.
   Skip `unity skill install` for now: those skills teach agents to edit scenes, which this workflow blocks.
4. **Smoke-test the gate** (30 seconds, from the project root):
   ```powershell
   '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"Assets/Test.prefab"}}' | powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\gate.ps1 PreToolUse
   ```
   You should see JSON containing `"permissionDecision":"deny"`. If you see an error instead, fix it before working — a hook that fails to run lets actions through (the `permissions.deny` rules in `settings.json` are the backup net).
5. **Start Claude Code** in the project folder and accept the workspace-trust prompt (hooks don't run until you do). Then type `/next-step`.

## A step, from your side

1. `/next-step` → the agent posts a plan and its questions. You answer (`1A 2C 3Y` works).
2. It codes, compiles through the Unity bridge, runs EditMode + PlayMode tests, and gives you **Editor steps** for anything in scenes or prefabs. You do those in Unity.
3. The **unity-architect** reviews: what was built, why, one traced example, file by file, Unity wiring, *where bugs would come from*, architecture check, drift, questions for the coding agent, and a 2–4 question quiz. Saved to `docs/reviews/step-<id>.md`.
4. The gate closes. You type one of:

| You type | What happens |
|---|---|
| your quiz answers | Architect grades them. Pass → gate opens. Partial → it teaches the gap and asks new questions. |
| `approve` | Accept the step without the quiz. |
| `rework` | The coding agent fixes what the review flagged, then a new review runs. |
| `arch-fix` | The architect rewrites the flagged parts itself, then you approve that fix. |
| `arch-update` | Accept an architecture change the review proposed; the architect updates the docs. |
| `skip-review` | Escape hatch: accept with no review at all (logged). |

5. Gate open → the agent gives you a commit message and file list (including `.meta` files). **You commit.**

Type gate words at the **start of a message**. Clicking an option on a question card does not count — that's deliberate, so no agent can approve its own work.

Anytime: `/explain <thing>` (add `simply`, `deeper`, or `the flow of`), `/where-am-i`, `/audit`. For bugs, just describe them — the agent diagnoses first (layer, cause, evidence, *how you could have found it*) and waits for your OK before fixing.

## What's enforced vs. what's trusted

**Enforced by hooks** (agents can't get around these):
- No code edits while a review is pending; no new step while changes are unreviewed
- Only the architect writes reviews and DECISIONS.md; only after `arch-update` can it change ARCHITECTURE.md; only after `arch-fix` can it change code
- No text edits to scenes, prefabs, assets, `.meta`, ProjectSettings, or the workflow's own files
- No git commits/pushes/resets; no moving or deleting `Assets/` files from the shell
- Unity bridge limited to console, compile, tests and read-only queries

**Trusted to instructions** (agents follow them, but nothing physically stops a mistake):
- Asking before off-doc decisions, posting a plan before coding
- Honest answers in "Questions for the coding agent"
- Not leaking the quiz answer key
- Fair grading by the architect

The gate log at `.claude/state/gate-log.txt` records every block and state change, so you can see if an agent kept trying something.

## Tuning

- Architect model: `model:` in `.claude/agents/unity-architect.md` (`opus` → `sonnet` to save usage).
- Unity tool allowlist: `$McpAllow` / `$McpDeny` in `gate.ps1`.
- Protected file types: `$UnityYaml` in `gate.ps1`.
- The architect keeps notes (drift patterns, your learning profile) in `.claude/agent-memory/unity-architect/MEMORY.md`. Read it sometimes — it's an honest picture of what you know and what to revisit.

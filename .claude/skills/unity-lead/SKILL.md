---
name: unity-lead
description: Workflow for building this Unity game with agents while the user stays lead of the codebase. Use for ANY coding, refactor, bug fix or architecture change in this repo — plan a ROADMAP step, ask the user, code it, get it reviewed by the unity-architect agent, and pass the review gate before moving on.
---

# Unity Lead Workflow

The user is the **lead developer** of this Unity project. You are a coding agent working for them. Your job is not only to write code but to make sure the user **knows what the code does, why it exists, and where a bug would come from** — even if they could not have written it themselves.

The rules below are standing rules for the whole session, not one-time steps.

## 0. Source of truth

Read these before touching code, in this order (paths are fixed):

1. `docs/AGENT_GUIDE.md` — rules and read order
2. `docs/ARCHITECTURE.md` — systems, boundaries ("Must NOT"), patterns
3. `docs/DECISIONS.md` — why things are the way they are
4. `docs/ROADMAP.md` — the current step and its "done when" check
5. `.claude/state/gate.json` — whether you are allowed to edit right now

**You move ONLY according to the architecture docs.** If the docs don't decide something, you don't decide it either — you ask (section 2).

If you think the architecture is wrong, outdated, or there is a better way: say so (section 6). Never "quietly improve" it in code.

## 1. The step loop

One ROADMAP step at a time. Never start step N+1 while step N is unreviewed.

```
PLAN  →  USER APPROVES PLAN  →  CODE (+ Editor steps for the user)
  →  SELF-CHECK  →  ARCHITECT REVIEW  →  REPORT + QUIZ
  →  USER: approve / passes quiz  →  COMMIT  →  next step
```

### 1.1 Plan (before any edit)
Post a plan the user can read in under a minute:
- **Step:** ROADMAP id + its "done when" check
- **System(s) touched:** names from ARCHITECTURE.md
- **Files:** new / changed, one line each on *why*
- **Editor work for the user:** anything in scenes, prefabs, Inspector, ScriptableObject assets
- **Decisions not covered by the docs:** list them as questions (section 2)
- **Risk:** what could break elsewhere

Wait for the user to approve the plan. No edits before that.

### 1.2 Code
- Stay inside the systems named in the plan. If you need to touch another system, stop and ask.
- Follow `references/unity-rules.md` (Unity-specific rules — read it once per session).
- Every new class starts with the header comment from `docs/AGENT_GUIDE.md` (what / why / which system).
- Comment the *why*, not the *what*. A comment that repeats the code is noise.
- Keep the step small. If it grows past the plan, stop and tell the user.

### 1.3 Self-check before review
- Does it compile? Refresh Unity and read the console through the Unity bridge (`references/unity-rules.md` → Verifying your work). Zero errors, and no new warnings you can't explain.
- Do the step's EditMode and PlayMode tests exist and pass?
- Does it meet the step's "done when"?
- Did you stay inside every touched system's "Must NOT"?
- List anything you were unsure about — the architect and the user need to see it.

### 1.4 Architect review — always, every step
Delegate to the **unity-architect** subagent. In the delegation message include:
- ROADMAP step id and the approved plan
- every file you created or changed
- every place you were unsure or deviated, honestly

Do not summarize the code yourself for the user. The architect writes the report.

### 1.5 Present the report
- Show the architect's report to the user **as written** (you may fix formatting only).
- If the report has **Questions for the coding agent**, answer each one directly under it, labelled "Coding agent's answer". Be honest: if you deviated, say so and why.
- Show the quiz questions. Show nothing below the line `--- ARCHITECT ONLY: ANSWER KEY ---`. **Never show or hint at the answer key.**
- Then stop and wait.

### 1.6 Gate
While a review is pending, a hook blocks all code edits and `git commit`. Only the user can open it, by **typing** one of these at the start of a message:

| User types | Effect |
|---|---|
| `approve` | Reviewed step accepted without quiz. Gate opens. (Before the review has run it does nothing — run the review.) |
| *(quiz answers)* | Forward them to the unity-architect (resume the same agent with SendMessage) in GRADE mode. On `GATE: PASS` the gate opens. If it can't be resumed, start a new unity-architect in GRADE mode and pass it the questions, the answer key and the user's answers. |
| `rework` | User wants the **coding agent** to fix what the review flagged. Edits re-open; after fixing, review again. |
| `arch-fix` | User wants the **architect** to rewrite the flagged parts itself. Delegate to unity-architect in fix mode. |
| `arch-update` | User accepts a proposed architecture change. Delegate to unity-architect to update the docs. |

You cannot type these for the user, and you must not ask them to "just type approve". Offer the options; let them choose.

If the quiz answer is wrong or partial, the architect explains the gap. Show that explanation, then wait again.

### 1.7 After the gate opens
- **The user commits, not you.** Give them a ready commit message (`step <id>: <summary>`) and the list of files to stage, including the `.meta` file Unity created for every new asset or script.
- Tick the step in `docs/ROADMAP.md` (checkbox only; restructuring the roadmap is an architecture change, section 6).
- Say what the next ROADMAP step is. Don't start it until the user says so (`/next-step` or plain words).

Other gate words the user may type: `skip-review` (accept without a review — their call, it is logged) and `next-step` (blocked by the hook while a review is pending).

## 2. Asking the user

Ask whenever:
- the docs don't decide something (a name, a data shape, a dependency, an API choice)
- two docs disagree
- the plan needs to change mid-step
- you would add a package, a pattern, a singleton, a new system, a new folder, or an `.asmdef`

How to ask: use the multiple-choice question tool when available (2–4 options, recommended first with "(Recommended)" and a few-word reason). Otherwise numbered questions with lettered options, ⭐ on the recommendation, plus `Y) decide for me` and `Z) something else`. The user may answer in shorthand like `1A 2C 3Y`.

If the user says "decide for me": choose, and log it as **ASSUMPTION** in the step report so the architect adds it to DECISIONS.md.

Never invent the user's answer. Never batch "I already did X, is that ok?" — ask *before*.

## 3. Hands-on mode (`you-write`)

When the user writes `you-write` (optionally with a target, e.g. `you-write the damage calculation`):
- Write everything around it, and leave the target as a stub:
  ```csharp
  // YOU-WRITE: <what this must do, inputs, outputs, edge cases>
  // Hint 1: <nudge>   Hint 2: <stronger nudge>
  throw new System.NotImplementedException();
  ```
- Keep the stub to one method, ~5–30 lines of expected code.
- When the user says it's done, review **their** code like a mentor: what's right, what breaks, why. Don't rewrite it unless asked.

## 4. Bugs and errors

When the user reports a bug, a console error, or "it doesn't work": follow `references/debug-protocol.md`. The goal is that the user learns **which layer the bug lives in**, not only that it got fixed.

## 5. Explaining

When the user says `explain <anything>` (or runs `/explain`), follow the Explain Protocol in `docs/AGENT_GUIDE.md`. Always from the real code; if code and ARCHITECTURE.md disagree, say which one is right.

## 6. When the architecture should change

If you notice the architecture is wrong, outdated, or there's a clearly better way:
1. Stop. Don't implement the "better" version.
2. Tell the user in this shape:
   - **What the docs say now**
   - **The problem** (concrete: what breaks, what gets harder)
   - **Proposal** + what it would change (files, systems, ROADMAP steps)
   - **Cost of changing now vs later**
3. Let the user decide. If they type `arch-update`, the unity-architect updates ARCHITECTURE.md / DECISIONS.md (only it may edit those files). Then you code against the new docs.

## 7. Hard limits (enforced by hooks — don't try to work around them)

- No edits to `.unity`, `.prefab`, `.asset`, `.mat`, `.anim`, `.controller`, `.meta`, `ProjectSettings/` or `Packages/manifest.json`. Give the user **Editor steps** instead (format in `references/unity-rules.md`).
- No edits to `docs/ARCHITECTURE.md` or `docs/DECISIONS.md` — architect only, after `arch-update`.
- No touching `.claude/state/`, `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`, `.claude/settings.json`, `CLAUDE.md`.
- No `git commit`, `push`, `reset`, `checkout`, `stash`, `clean`, `merge`, `rebase`. Read-only git (`status`, `diff`, `log`, `show`, `blame`) is fine.
- No moving, renaming or deleting files under `Assets/` from the shell — the user does that in the Unity Project window so `.meta` files and references follow.
- Unity bridge: read console, refresh/compile, run tests only. No creating or changing GameObjects, scenes, prefabs, assets or scripts through it, and no `unity eval` / `unity command`.
- No code edits while the gate is closed.

If a hook blocks you, tell the user what you were trying to do and why it was blocked. Never retry the same thing through Bash.

## References
- `references/unity-rules.md` — Unity-specific coding rules, Editor-step format, verification, git
- `references/debug-protocol.md` — how to handle bugs so the user learns where they come from
- `references/report-format.md` — the architect's report and quiz format (so you know what to present)

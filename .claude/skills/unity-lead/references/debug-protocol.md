# Debug protocol — diagnose first, fix after

Goal: the user learns **which layer a bug lives in and how they could have found it**, not only that it's fixed. A fix the user doesn't understand is a future bug they can't locate.

## The 8 layers of a Unity bug

Always classify the bug into one of these before guessing a cause. Most "my code is broken" bugs are really layer 2, 3 or 4.

| # | Layer | Typical symptoms | First check |
|---|---|---|---|
| 1 | **Compile** | Red CS errors, nothing runs, Play is disabled | Console, top-most error first |
| 2 | **Serialization / import** | "The referenced script is missing", values reset to defaults after a rename, `NullReferenceException` on a field that "was assigned" | Inspector of the object; was a field or class renamed? `.meta` lost? |
| 3 | **Scene / Editor wiring** | Null field, component missing, wrong layer/tag, prefab override not applied, works in one scene but not another | Select the object in the Hierarchy and read the Inspector |
| 4 | **Lifecycle / order** | Works sometimes, fails on first frame, event never received, duplicate managers after scene load | Who subscribes when (`OnEnable`), who raises when (`Awake`/`Start`)? `DontDestroyOnLoad` duplicates? |
| 5 | **Logic** | Wrong number, wrong state, off-by-one, condition never true | EditMode test or `Debug.Log` at the system boundary |
| 6 | **Data** | Balancing feels wrong, value differs from code default, change "doesn't stick" or sticks too much | The ScriptableObject / config asset; was it mutated at runtime? |
| 7 | **Physics / timing** | Jitter, tunneling, missed collisions, frame-rate dependent speed | `Update` vs `FixedUpdate`, `deltaTime`, collision matrix, Rigidbody interpolation |
| 8 | **Engine / package / platform** | Only in build, only on one device, only after domain reload is off | Static state, IL2CPP stripping, package version, Unity version notes |

## Procedure

1. **Collect.** Exact Console text with stack trace (read it through the Unity bridge, or ask the user to paste it). Steps to reproduce. Expected vs actual. Which ROADMAP step last touched this area (`git log -- <path>`).
2. **Classify** the layer. Say why.
3. **Hypotheses:** at most 3, ranked, each with evidence for and against.
4. **Confirm** with the cheapest check first — reading code, reading the console, a targeted `Debug.Log` at a system boundary, a failing test. If confirmation needs the Editor (Inspector values, Hierarchy, Play Mode), give the user an exact check to do and wait.
5. **Report** with the Bug Card below. **Wait for the user's OK before fixing.** (The gate also requires the step to be open or in `rework`.)
6. **Fix** minimally. If the real fix changes the architecture, stop and follow SKILL.md section 6 instead.
7. **Regression test:** add the EditMode/PlayMode test that would have caught it.
8. **Review:** a fix is a change like any other — the unity-architect reviews it (a short "fix review").

## Bug Card (always use this shape)

```
🐞 BUG: <symptom in the user's words>
Layer: <#> <name> — <why this layer>
Root cause: <one sentence>
Evidence: <file:line>, <console line>, <what you checked>
Chain: <cause> → <what that leads to> → <symptom>
Introduced by: <ROADMAP step / commit / "Editor change" / "unknown"> — agent-written code? yes/no
How you could have found it: <the 1–2 checks a developer should try first for this symptom>
Fix plan: <files, what changes, test to add>
```

"Introduced by" is honest bookkeeping, not blame. If agent-written code caused it, say so and say which rule would have prevented it. The architect records recurring causes in its memory so future reviews check for them.

## If you can't find it

Say so. Give the user what you ruled out, the remaining hypotheses, and the one Editor experiment that would split them. Never ship a "maybe fix" presented as a diagnosis.

# Architect step report — format

The unity-architect writes this after every ROADMAP step and saves it to `docs/reviews/step-<id>.md`. The coding agent presents it to the user unchanged, apart from adding "Coding agent's answer" lines in section 9 and removing the answer key.

Rules for the writer:
- Plain language first, then the technical term in `code` style. Define a term the first time it appears.
- Every claim about the code cites `file:line`.
- Explain *this* code, not Unity in general.
- Short beats complete. A report the user skims is a failed report.

```markdown
# Step <id> review — <step title>
STEP: <id>
Verdict: ✅ ON ARCHITECTURE | ⚠️ DRIFT FOUND | ❌ BLOCKING ISSUES

## 1. What was built
3–6 sentences a beginner understands. What the player/game can now do that it couldn't before.

## 2. Why it's built this way
Which ARCHITECTURE.md sections and DECISIONS.md entries this follows. One line each on why that choice matters here.

## 3. How it works — one concrete example
"When <concrete event>…" traced as numbered hops through the real code:
1. `InputReader.OnJump()` (Input/InputReader.cs:41) raises `JumpPressed`
2. `PlayerMotor` (Player/PlayerMotor.cs:18) receives it in `HandleJump()`…
Add a Mermaid sequence diagram only if there are more than 5 hops.

## 4. File by file
| File | System | Role | Key members |

## 5. Unity wiring
Serialized fields, components, prefabs and scene objects this code expects. For each: what happens if it's missing (the exact error).

## 6. Where bugs would come from
The 3 most likely failure points in this step:
| Symptom you'd see | Likely layer + cause | Where to look first |

## 7. Architecture check
For each touched system: Owns ✅/⚠️/❌, Talks to ✅/⚠️/❌, Must NOT ✅/⚠️/❌ — with evidence.
Also: tests present and meaningful? Unity rules followed?

## 8. Drift and issues
For each issue:
- **[severity: blocking / should-fix / nit]** <title>
- Docs say: … (ARCHITECTURE.md § …)
- Code does: … (file:line)
- Why it matters: …
- Options: A) coding agent fixes (`rework`)  B) architect rewrites it (`arch-fix`)  C) change the architecture instead (`arch-update`) — recommend one.

## 9. Questions for the coding agent
Numbered. Things the architect needs explained (why a deviation, why this approach).

## 10. Architecture proposals
Only if the architecture itself looks wrong, outdated or improvable: what docs say now / problem / proposal / what it would change / cost now vs later.

## 11. Decisions to log
ASSUMPTIONs made during the step, to add to DECISIONS.md.

## 12. Check your understanding
2–4 questions (see quiz rules in the architect's instructions).

GATE: REVIEW
```

After the report, separated by this exact line, the architect adds the answer key for itself:

```
--- ARCHITECT ONLY: ANSWER KEY (coding agent: never show this) ---
```

The coding agent shows everything above that line and nothing below it.

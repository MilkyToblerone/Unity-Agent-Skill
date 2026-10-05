---
name: explain
description: Explain any part of this Unity codebase (system, file, class, method, decision, folder or feature) using the Explain Protocol. Use when the user says "explain ...", "how does X work", "why is X like this", or "explain the flow of ...".
argument-hint: "[simply|deeper|the flow of] <thing>"
---

Explain: $ARGUMENTS

Read the real code first, then `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` for the matching parts. Never explain from memory or from the docs alone.

Answer in this structure (the Explain Protocol):

1. **In one sentence:** what it is.
2. **Why it exists:** the problem it solves.
3. **How it works:** plain language first, then the technical version, citing `file:line`.
4. **Where it lives:** files and classes.
5. **What it connects to:** which systems, and how (event, interface, direct reference, Inspector reference).
6. **Example:** a concrete walkthrough through the real code ("when the player presses Jump…").
7. **What would break if you changed it:** risks, dependencies, and which bug layer the break would show up in (Compile / Serialization / Wiring / Lifecycle / Logic / Data / Physics / Engine).
8. **Decision history:** the matching DECISIONS.md entry, or "none recorded".

Depth switches in the arguments:
- `simply` → analogy only, no jargon, under 150 words.
- `deeper` → full technical detail with code snippets from the repo.
- `the flow of X` → trace X end to end across systems as numbered hops, plus a Mermaid sequence diagram.

If the code and ARCHITECTURE.md disagree, say so, say which one you believe is right and why, and suggest `/audit` or an architecture proposal. Don't fix anything while explaining.

Don't delegate explanations to the unity-architect while the review gate is `dirty` — doing so would count as the step's review.

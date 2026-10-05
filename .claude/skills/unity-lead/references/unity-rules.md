# Unity rules for coding agents (Unity 6 / C#)

These apply on top of `docs/ARCHITECTURE.md`. If the architecture says something different, the architecture wins — and you mention the conflict to the user.

## 1. Files Unity owns — never edit them as text

Scenes (`.unity`), prefabs (`.prefab`), ScriptableObject/other assets (`.asset`), materials, animation clips and controllers, `.meta` files, `ProjectSettings/`, `Packages/manifest.json`.

Why: these are YAML that Unity serializes with GUIDs and fileIDs. A text edit that looks right can silently break references, merges, or a prefab's overrides. Hooks block these edits.

Instead, write **Editor steps** for the user, in this exact shape:

```
🛠 EDITOR STEPS — do these in Unity
1. Open scene `Assets/Scenes/Main.unity`.
2. Select `Player` in the Hierarchy → Add Component → `PlayerHealth`.
3. In PlayerHealth, drag `Assets/Data/PlayerStats.asset` into the **Stats** field.
✅ Check: press Play. The Console shows `PlayerHealth ready (100 HP)`.
❌ If you see `NullReferenceException … PlayerHealth.cs:23`, step 3 was skipped.
```

Every Editor step list ends with a check the user can do, and the most likely failure if a step was missed. That last line is how the user learns where wiring bugs come from.

Moving, renaming or deleting scripts and assets: the user does it in the **Project window**, never from the shell. The `.meta` file (and its GUID) must move with the file or every reference to it breaks.

New `.cs` files are fine to create. Unity generates the `.meta` on import — remind the user to commit it.

## 2. Serialization rules

- Use `[SerializeField] private` fields, not public fields, for Inspector values. Expose read-only properties if others need the value.
- The MonoBehaviour / ScriptableObject class name must match the file name. One per file.
- **Renaming a serialized field wipes its value in every scene and prefab.** If you must rename, add `[FormerlySerializedAs("oldName")]` and tell the user in the plan.
- Changing a serialized field's type also loses data. Treat it like a rename: ask first.
- ScriptableObject values changed at runtime **stay changed in the Editor** after Play Mode. Never write runtime state into a ScriptableObject unless the architecture says so.
- `[CreateAssetMenu]` on new ScriptableObjects so the user can create them from the Project window.

## 3. Unity-specific C# traps (the classic agent mistakes)

- **Unity null:** never use `?.`, `??` or `is null` on `UnityEngine.Object` (GameObject, Component, ScriptableObject). Destroyed objects are "fake null" and these operators skip Unity's check. Use `if (thing == null)` or `if (!thing)`.
- **Lifecycle:** `Awake` = get your own references. `OnEnable` = subscribe to events. `OnDisable` = unsubscribe (always pair them). `Start` = talk to other objects. Don't rely on the order of `Awake` between different objects.
- **Static state:** if Enter Play Mode Options skip domain reload, statics survive between Play sessions. Reset them explicitly (`[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]`) or avoid them.
- **Unity 6 API names:** `Rigidbody.linearVelocity` (not `velocity`), `linearDamping` / `angularDamping` (not `drag` / `angularDrag`), `FindFirstObjectByType` / `FindAnyObjectByType` / `FindObjectsByType` (not `FindObjectOfType`). If unsure whether an API exists in this Unity version, check — don't guess.
- **Physics:** move Rigidbodies in `FixedUpdate`, read input in `Update`. Triggers need a Rigidbody on at least one side. Check the layer collision matrix before blaming code.
- **Hot paths (`Update`, `FixedUpdate`, per-frame code):** no `GetComponent`, `Find*`, LINQ, string building or `new` of reference types. Cache in `Awake`.
- **Coroutines** stop when their GameObject is disabled. For async work prefer what the architecture specifies (`Awaitable` in Unity 6, coroutines, or UniTask) — never `async void` except Unity event handlers.
- **Strings for tags, layers, animator params, scene names:** use constants or `Animator.StringToHash`, never repeat literals.
- **Singletons, `DontDestroyOnLoad`, new packages, new `.asmdef` files:** only if ARCHITECTURE.md allows them. Otherwise ask.

## 4. Verifying your work (Unity bridge)

The project uses the **Unity CLI's MCP server** (`unity mcp configure claude`) to reach the running Editor.

Allowed through the bridge:
- refresh / recompile scripts
- read the Console (errors, warnings, logs)
- run EditMode and PlayMode tests and read results
- read-only queries (editor state, find/list objects)

Blocked (by hook and by rule): anything that creates or changes GameObjects, components, scenes, prefabs, assets or scripts; executing menu items; `unity eval`; `unity command`. Scripts change only through Edit/Write so the gate and the review see every change.

After writing code: refresh → read console → fix compile errors → run the step's EditMode tests → run its PlayMode tests.

If the Editor isn't open or the bridge isn't connected: say so plainly and ask the user to open Unity, or to paste the Console output. Don't claim it compiles if you couldn't check.

## 5. Tests (every step)

- **EditMode** tests for pure logic: rules, math, state machines, data transforms. Put game logic in plain C# classes where the architecture allows, so it's testable without a scene.
- **PlayMode** tests (`[UnityTest]`, `IEnumerator`) for behaviour that needs frames, physics, or components talking. Build test objects in code; don't load production scenes unless the architecture says so.
- Location: `Assets/Tests/EditMode/` and `Assets/Tests/PlayMode/`, each with its own test `.asmdef` referencing the game assemblies. Creating those `.asmdef` files the first time is a structural decision: ask.
- At least one test proves the step's "done when", whenever that's testable. If it isn't (pure feel / visuals), say so in the plan.
- Tests are code too: the architect reviews them. A test that can't fail is worse than no test.

## 6. Git

The user commits. You may run `git status`, `git diff`, `git log`, `git show`, `git blame`. Nothing that changes history or the working tree.

After the gate opens, give the user:
```
Suggested commit:  step 3.2: player takes damage from hazards
Stage:  Assets/Scripts/Health/PlayerHealth.cs (+ .meta)
        Assets/Tests/EditMode/HealthTests.cs (+ .meta)
        Assets/Scenes/Main.unity   ← you changed this in the Editor (step 2)
```
Remind them that `.meta` files are always committed together with their asset.

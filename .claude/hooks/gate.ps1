# gate.ps1 - Review gate for the unity-lead workflow.
#
# What:  One script for every hook event. Claude Code passes the event as JSON on stdin.
#        The script keeps .claude/state/gate.json and allows or blocks agent actions.
# Why:   So no agent can skip the architect review, approve its own work, or edit files
#        only the user (or the architect, when the user says so) may edit.
# Where: Registered in .claude/settings.json. Written for Windows PowerShell 5.1.
#
# Gate states:
#   open    - nothing unreviewed. Agents may edit code; the first code edit makes it "dirty".
#   dirty   - code changed, not reviewed yet. Edits allowed. next-step is blocked.
#   pending - architect reviewed. Code edits blocked until the user types approve,
#             passes the quiz (architect writes "GATE: PASS"), or types rework / arch-fix.

param([string]$HookEvent = '')

$ErrorActionPreference = 'Stop'
# Turkish (and some other) locales lowercase 'I' to a dotless i, which breaks case-insensitive
# path matching. Run the whole script in the invariant culture.
try { [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture } catch {}
try { [Console]::InputEncoding  = New-Object System.Text.UTF8Encoding $false } catch {}
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

$ArchitectName = 'unity-architect'

# ---------- helpers ----------

function Norm([string]$p) {
    if ([string]::IsNullOrEmpty($p)) { return '' }
    return ($p -replace '\\', '/').TrimEnd('/')
}

function Out-Json($obj) {
    Write-Output ($obj | ConvertTo-Json -Depth 6 -Compress)
}

function Write-Log([string]$text) {
    try {
        [System.IO.Directory]::CreateDirectory($script:StateDir) | Out-Null
        $line = (Get-Date).ToString('s') + "  [$script:Evt]  " + $text + [Environment]::NewLine
        [System.IO.File]::AppendAllText($script:LogPath, $line, (New-Object System.Text.UTF8Encoding $false))
    } catch {}
}

function Load-State {
    $s = $null
    if ([System.IO.File]::Exists($script:StatePath)) {
        try { $s = [System.IO.File]::ReadAllText($script:StatePath) | ConvertFrom-Json } catch { $s = $null }
    }
    $h = [ordered]@{ status = 'open'; step = ''; changed = @(); archFix = $false; archUpdate = $false; updated = '' }
    if ($s) {
        if ($s.status)     { $h.status = [string]$s.status }
        if ($s.step)       { $h.step = [string]$s.step }
        if ($s.changed)    { $h.changed = @($s.changed | ForEach-Object { [string]$_ }) }
        if ($s.archFix)    { $h.archFix = [bool]$s.archFix }
        if ($s.archUpdate) { $h.archUpdate = [bool]$s.archUpdate }
    }
    return $h
}

function Save-State($h) {
    [System.IO.Directory]::CreateDirectory($script:StateDir) | Out-Null
    $h.updated = (Get-Date).ToString('s')
    $copy = [ordered]@{
        status     = $h.status
        step       = $h.step
        changed    = [string[]]@($h.changed)
        archFix    = $h.archFix
        archUpdate = $h.archUpdate
        updated    = $h.updated
    }
    $json = ConvertTo-Json -InputObject $copy -Depth 4
    [System.IO.File]::WriteAllText($script:StatePath, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Deny([string]$reason) {
    Write-Log ("DENY  " + $reason)
    Out-Json @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } }
    exit 0
}

function Add-Context([string]$eventName, [string]$text) {
    Out-Json @{ hookSpecificOutput = @{ hookEventName = $eventName; additionalContext = $text } }
}

function Block-Prompt([string]$reason) {
    Write-Log ("BLOCK " + $reason)
    Out-Json @{ decision = 'block'; reason = $reason }
    exit 0
}

function Get-Rel([string]$path) {
    $p = Norm $path
    if ($p -eq '') { return $null }
    $root = $script:ProjN
    if ($root -ne '' -and $p.StartsWith($root + '/', [System.StringComparison]::OrdinalIgnoreCase)) { return $p.Substring($root.Length + 1) }
    $rooted = [System.IO.Path]::IsPathRooted($path) -or ($p -match '^[A-Za-z]:/') -or $p.StartsWith('/')
    if (-not $rooted) { return ($p -replace '^\./', '') }
    return $null   # outside the project: not our business
}

function Step-Label($h) { if ($h.step) { return "step " + $h.step } else { return "the current step" } }

$UnityYaml   = '(?i)\.(unity|prefab|asset|mat|anim|controller|overridecontroller|meta|physicmaterial|physicsmaterial2d|lighting|lightingdata|playable|signal|mask|rendertexture|spriteatlas|spriteatlasv2|terrainlayer|guiskin|fontsettings|flare|cubemap|shadervariants|mixer|brush|preset)$'
$UnityDirs   = '(?i)^(ProjectSettings|UserSettings|Library|Logs|Temp)/|^Packages/(manifest|packages-lock)\.json$'
$Infra       = '(?i)^\.claude/(state|hooks|agents|skills)/|^\.claude/settings(\.local)?\.json$|^CLAUDE\.md$'
$CodePath    = '(?i)^(Assets|Packages)/'
$GatePathRe  = '(?i)\.claude[\\/](state|hooks|agents|skills)|\.claude[\\/]settings|gate\.json|CLAUDE\.md'
$GitWrite    = '(?i)\bgit\s+(commit|push|reset|rebase|merge|cherry-pick|revert|stash|clean|checkout|switch|restore|rm|mv|am|apply|tag|branch\s+-[dDmM])\b'
$UnityCliRe  = '(?i)\bunity(\.exe)?\s+(eval|command)\b'
$ProtectedFs = '(?i)\b(assets|projectsettings|packages)[\\/]|docs[\\/](architecture|decisions|agent_guide)\.md|docs[\\/]reviews'
$ShellWrite  = '(?i)(?<![0-9&])>{1,2}(?!&)|\b(set-content|add-content|out-file|new-item|remove-item|move-item|rename-item|copy-item|rm|del|erase|mv|cp|move|rename|copy|xcopy|robocopy|tee|touch|mkdir|rmdir)\b|sed\s+-i|\[io\.file\]::write'
$McpAllow    = '(?i)(console|logs?\b|log_|test|refresh|compile|status|ping|editor_state|get_|list_|find|search|read|resource|info|diagnos)'
$McpDeny     = '(?i)(manage_|create|delete|modify|apply|edit|write|set_|update|execute|eval|batch|import|instantiate|add_|remove|destroy|save|menu)'

# ---------- main ----------

$script:Evt = $HookEvent
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $data = $raw | ConvertFrom-Json
    if ($data.hook_event_name) { $script:Evt = [string]$data.hook_event_name }

    $proj = $env:CLAUDE_PROJECT_DIR
    if ([string]::IsNullOrEmpty($proj)) { $proj = [string]$data.cwd }
    $script:ProjN     = Norm $proj
    $script:StateDir  = $script:ProjN + '/.claude/state'
    $script:StatePath = $script:StateDir + '/gate.json'
    $script:LogPath   = $script:StateDir + '/gate-log.txt'

    $agentType   = [string]$data.agent_type
    $isArchitect = ($agentType -eq $ArchitectName)
    $who = if ($agentType) { $agentType } else { 'main' }

    switch ($script:Evt) {

        'PreToolUse' {
            $tool = [string]$data.tool_name
            $in = $data.tool_input

            if ($tool -match '^(Edit|Write|MultiEdit|NotebookEdit)$') {
                $path = [string]$in.file_path
                if (-not $path) { $path = [string]$in.notebook_path }
                $rel = Get-Rel $path
                if ($null -eq $rel) { exit 0 }

                if ($rel -match $Infra) {
                    Deny "Blocked: '$rel' is part of the workflow setup (.claude config, hooks, gate state, CLAUDE.md). Only the user edits these by hand."
                }
                if ($rel -match $UnityYaml -or $rel -match $UnityDirs) {
                    Deny "Blocked: '$rel' is a Unity-serialized file (scene, prefab, asset, .meta or project settings). Don't edit it as text. Write numbered EDITOR STEPS for the user instead (format in .claude/skills/unity-lead/references/unity-rules.md)."
                }
                $s = Load-State
                if ($rel -match '(?i)^docs/(ARCHITECTURE|AGENT_GUIDE)\.md$') {
                    if ($isArchitect -and $s.archUpdate) { exit 0 }
                    Deny "Blocked: '$rel' changes only through the unity-architect after the user types arch-update. Propose the change to the user instead (unity-lead section 6)."
                }
                if ($rel -match '(?i)^docs/DECISIONS\.md$' -or $rel -match '(?i)^docs/reviews/') {
                    if ($isArchitect) { exit 0 }
                    Deny "Blocked: '$rel' is written by the unity-architect only."
                }
                if ($rel -match $CodePath) {
                    if ($isArchitect) {
                        if ($s.archFix) { exit 0 }
                        Deny "Blocked: the architect may change code only after the user types arch-fix. Report the problem instead."
                    }
                    if ($s.status -eq 'pending') {
                        Deny ("Blocked: the review of " + (Step-Label $s) + " is waiting for the user. Code edits stay locked until the user types approve, passes the quiz, types rework (you fix) or arch-fix (architect fixes). Tell the user what you wanted to change and why.")
                    }
                    exit 0
                }
                exit 0
            }

            if ($tool -match '^(Bash|PowerShell)$') {
                $cmd = [string]$in.command
                if ($cmd -match $GatePathRe) {
                    Deny "Blocked: shell commands may not touch the workflow setup (.claude config, hooks, gate state, CLAUDE.md). Use the Read tool to read gate.json."
                }
                if ($cmd -match $GitWrite) {
                    Deny "Blocked: the user handles git. You may use git status / diff / log / show / blame. Give the user a suggested commit message and file list instead."
                }
                if ($cmd -match $UnityCliRe) {
                    Deny "Blocked: 'unity eval' and 'unity command' can change scenes and assets outside the review. Use the Unity MCP tools for console, refresh and tests only."
                }
                if ($cmd -match $ProtectedFs -and $cmd -match $ShellWrite) {
                    Deny "Blocked: don't write, move, rename or delete project files from the shell. Change code with Edit/Write so the gate and the review see it; moves, renames and deletes under Assets/ are done by the user in the Unity Project window so .meta files follow."
                }
                exit 0
            }

            if ($tool -like 'mcp__*') {
                $parts = $tool -split '__'
                if ($parts.Count -ge 3) {
                    $server = $parts[1]
                    $name = ($parts[2..($parts.Count - 1)] -join '__')
                    if ($server -match '(?i)unity') {
                        if ($name -match $McpDeny -or -not ($name -match $McpAllow)) {
                            Deny "Blocked: Unity tool '$name' is not on the read-only list (console, refresh/compile, tests, read-only queries). Scene, prefab, asset and script changes go through Edit/Write or Editor steps for the user."
                        }
                    }
                }
                exit 0
            }
            exit 0
        }

        'PostToolUse' {
            $tool = [string]$data.tool_name
            if ($tool -notmatch '^(Edit|Write|MultiEdit|NotebookEdit)$') { exit 0 }
            $path = [string]$data.tool_input.file_path
            if (-not $path) { $path = [string]$data.tool_input.notebook_path }
            $rel = Get-Rel $path
            if ($null -eq $rel -or $rel -notmatch $CodePath) { exit 0 }
            $s = Load-State
            if ($s.status -eq 'open') { $s.status = 'dirty'; Write-Log "open -> dirty (first change by ${who}: ${rel})" }
            if (-not ($s.changed -contains $rel)) { $s.changed = @($s.changed) + $rel }
            Save-State $s
            exit 0
        }

        'SubagentStop' {
            if (-not $isArchitect) { exit 0 }
            $msg = [string]$data.last_assistant_message
            $s = Load-State
            if ($msg -match '(?m)^\s*STEP:\s*(\S+)') { $s.step = $Matches[1] }
            # Only the part above the answer-key separator counts.
            $visible = ($msg -split '--- ARCHITECT ONLY')[0]
            if ($s.status -eq 'dirty') {
                $s.status = 'pending'
                Write-Log ("dirty -> pending (architect reviewed " + (Step-Label $s) + ")")
            } elseif ($s.status -eq 'pending' -and $visible -match '(?m)^\s*GATE:\s*PASS\s*$') {
                $s.status = 'open'; $s.changed = @()
                Write-Log ("pending -> open (quiz passed, " + (Step-Label $s) + ")")
            }
            $s.archFix = $false; $s.archUpdate = $false
            Save-State $s
            exit 0
        }

        'UserPromptSubmit' {
            $prompt = ([string]$data.prompt).Trim()
            $first = (($prompt -split '\s+')[0]).ToLower().TrimStart('/').TrimEnd('.', '!', ',', ':')
            $s = Load-State
            $label = Step-Label $s
            switch ($first) {
                'approve' {
                    if ($s.status -eq 'pending') {
                        $s.status = 'open'; $s.changed = @(); $s.archFix = $false; $s.archUpdate = $false; Save-State $s
                        Write-Log "pending -> open (user typed approve, $label)"
                        Add-Context 'UserPromptSubmit' "Review gate: the user typed approve, so $label is accepted and the gate is open. The user commits the changes themselves; give them the suggested commit message and file list."
                    } elseif ($s.status -eq 'dirty') {
                        Add-Context 'UserPromptSubmit' "Review gate: the user typed approve, but the changes of $label have not been reviewed by the unity-architect yet, so the gate stays as it is. The review runs first. (The user can type skip-review to skip it.)"
                    } else {
                        Add-Context 'UserPromptSubmit' "Review gate: the user typed approve; the gate is already open."
                    }
                    exit 0
                }
                'skip-review' {
                    if ($s.status -ne 'open' -or $s.archFix -or $s.archUpdate) {
                        $s.status = 'open'; $s.changed = @(); $s.archFix = $false; $s.archUpdate = $false; Save-State $s
                        Write-Log "-> open (user typed skip-review, $label)"
                    }
                    Add-Context 'UserPromptSubmit' "Review gate: the user typed skip-review, so $label is accepted without an architect review. The gate is open."
                    exit 0
                }
                'rework' {
                    if ($s.status -eq 'pending') {
                        $s.status = 'dirty'; Save-State $s
                        Write-Log "pending -> dirty (user typed rework, $label)"
                    }
                    Add-Context 'UserPromptSubmit' "Review gate: the user typed rework. The coding agent may edit code again to address the review of $label. A new unity-architect review is required afterwards."
                    exit 0
                }
                'arch-fix' {
                    $s.archFix = $true; Save-State $s
                    Write-Log "archFix on (user typed arch-fix, $label)"
                    Add-Context 'UserPromptSubmit' "Review gate: the user typed arch-fix. The unity-architect may now rewrite the code the user chose in FIX mode. The coding agent still may not edit code while the review is pending."
                    exit 0
                }
                'arch-update' {
                    $s.archUpdate = $true; Save-State $s
                    Write-Log "archUpdate on (user typed arch-update)"
                    Add-Context 'UserPromptSubmit' "Review gate: the user typed arch-update. The unity-architect may now update docs/ARCHITECTURE.md and related docs in UPDATE mode."
                    exit 0
                }
                'next-step' {
                    if ($s.status -ne 'open') {
                        Block-Prompt ("The review gate is '" + $s.status + "' for $label, so a new step can't start yet. Finish the review first: approve, answer the quiz, rework, arch-fix, or skip-review.")
                    }
                    exit 0
                }
                default {
                    if ($s.status -eq 'pending') {
                        Add-Context 'UserPromptSubmit' "Review gate status: pending for $label. Code edits are locked. If this message answers the quiz, forward it to the unity-architect (resume it with SendMessage) for grading."
                    }
                    exit 0
                }
            }
        }

        'UserPromptExpansion' {
            if (([string]$data.command_name) -match '(?i)(^|:)next-step$') {
                $s = Load-State
                if ($s.status -ne 'open') {
                    Block-Prompt ("The review gate is '" + $s.status + "' for " + (Step-Label $s) + ", so a new step can't start yet. Finish the review first: approve, answer the quiz, rework, arch-fix, or skip-review.")
                }
            }
            exit 0
        }

        'SessionStart' {
            $s = Load-State
            $files = if (@($s.changed).Count -gt 0) { ' Changed files: ' + (@($s.changed) -join ', ') + '.' } else { '' }
            Write-Output ("Review gate status: " + $s.status + " (" + (Step-Label $s) + ")." + $files + " The unity-lead skill defines what each status allows.")
            exit 0
        }

        default { exit 0 }
    }
}
catch {
    $err = $_.Exception.Message
    try { Write-Log ("ERROR " + $err) } catch {}
    if ($script:Evt -eq 'PreToolUse') {
        # Fail closed for actions: a broken gate must not silently let everything through.
        Out-Json @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = "Review-gate hook error: $err. Tell the user the gate script needs fixing (.claude/hooks/gate.ps1)." } }
        exit 0
    }
    [Console]::Error.WriteLine("gate.ps1 error: $err")
    exit 1
}

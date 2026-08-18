$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
Set-Location $projectRoot

$nl = "`n"
$fence = '```'

function Update-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][scriptblock]$Updater
    )

    $content = (Get-Content -Path $Path -Raw) -replace "`r`n", "`n"
    $updated = & $Updater $content

    if ($updated -ne $content) {
        Set-Content -Path $Path -Value $updated -NoNewline
        Write-Host "Updated $Path"
    } else {
        Write-Host "No changes needed for $Path"
    }
}

Update-TextFile ".agents/stages/code-quality-fix.md" {
    param($content)

    if (-not $content.Contains("scripts\check-architecture-rules.cmd")) {
        $oldBlock = "bash scripts/check-architecture-rules.sh${nl}${fence}"
        $newBlock = "bash scripts/check-architecture-rules.sh${nl}${fence}${nl}${nl}" +
            "On Windows (using PowerShell or Command Prompt), run the native script launchers instead:${nl}" +
            "${fence}powershell${nl}" +
            "scripts\check-compose-rules.cmd${nl}" +
            "scripts\check-localization-rules.cmd${nl}" +
            "scripts\check-architecture-rules.cmd${nl}${fence}"
        $content = $content.Replace($oldBlock, $newBlock)
    }

    $oldGate = '- [ ] `bash scripts/check-compose-rules.sh` — exit code 0 (or skipped if no UI changed)' + $nl +
        '- [ ] `bash scripts/check-localization-rules.sh` — exit code 0' + $nl +
        '- [ ] `bash scripts/check-architecture-rules.sh` — exit code 0'
    $newGate = '- [ ] `bash scripts/check-compose-rules.sh` or `scripts\check-compose-rules.cmd` — exit code 0 (or skipped if no UI changed)' + $nl +
        '- [ ] `bash scripts/check-localization-rules.sh` or `scripts\check-localization-rules.cmd` — exit code 0' + $nl +
        '- [ ] `bash scripts/check-architecture-rules.sh` or `scripts\check-architecture-rules.cmd` — exit code 0'
    $content = $content.Replace($oldGate, $newGate)

    return $content
}

Update-TextFile ".agents/skills/android-code-review/SKILL.md" {
    param($content)

    if (-not $content.Contains("scripts\check-architecture-rules.cmd")) {
        $oldBlock = "bash scripts/check-architecture-rules.sh${nl}${fence}"
        $newBlock = "bash scripts/check-architecture-rules.sh${nl}${fence}${nl}${nl}" +
            "On Windows (using PowerShell or Command Prompt), run the native script launchers instead:${nl}" +
            "${fence}powershell${nl}" +
            "scripts\check-compose-rules.cmd${nl}" +
            "scripts\check-localization-rules.cmd${nl}" +
            "scripts\check-architecture-rules.cmd${nl}${fence}"
        $content = $content.Replace($oldBlock, $newBlock)
    }

    $oldGate = '- [ ] `check-compose-rules.sh` — exit code 0 (or skipped with no Compose changes)' + $nl +
        '- [ ] `check-localization-rules.sh` — exit code 0' + $nl +
        '- [ ] `check-architecture-rules.sh` — exit code 0'
    $newGate = '- [ ] `check-compose-rules.sh` or `check-compose-rules.cmd` — exit code 0 (or skipped with no Compose changes)' + $nl +
        '- [ ] `check-localization-rules.sh` or `check-localization-rules.cmd` — exit code 0' + $nl +
        '- [ ] `check-architecture-rules.sh` or `check-architecture-rules.cmd` — exit code 0'
    $content = $content.Replace($oldGate, $newGate)

    return $content
}

Update-TextFile ".agents/skills/android-code-quality-checks/SKILL.md" {
    param($content)

    if (-not $content.Contains("scripts\check-architecture-rules.cmd")) {
        $oldBlock = "   bash scripts/check-architecture-rules.sh${nl}   ${fence}"
        $newBlock = "   bash scripts/check-architecture-rules.sh${nl}   ${fence}${nl}${nl}" +
            "   On Windows (using PowerShell or Command Prompt), run the native script launchers instead:${nl}" +
            "   ${fence}powershell${nl}" +
            "   scripts\check-compose-rules.cmd${nl}" +
            "   scripts\check-localization-rules.cmd${nl}" +
            "   scripts\check-architecture-rules.cmd${nl}   ${fence}"
        $content = $content.Replace($oldBlock, $newBlock)
    }

    $oldGate = '- [ ] `bash scripts/check-compose-rules.sh` passes (0 violations).' + $nl +
        '- [ ] `bash scripts/check-localization-rules.sh` passes (0 violations).' + $nl +
        '- [ ] `bash scripts/check-architecture-rules.sh` passes (0 violations).'
    $newGate = '- [ ] `bash scripts/check-compose-rules.sh` or `scripts\check-compose-rules.cmd` passes (0 violations).' + $nl +
        '- [ ] `bash scripts/check-localization-rules.sh` or `scripts\check-localization-rules.cmd` passes (0 violations).' + $nl +
        '- [ ] `bash scripts/check-architecture-rules.sh` or `scripts\check-architecture-rules.cmd` passes (0 violations).'
    $content = $content.Replace($oldGate, $newGate)

    return $content
}

Update-TextFile ".agents/gates/ci-checks.md" {
    param($content)

    if (-not $content.Contains("scripts\check-compose-rules.cmd")) {
        $oldBlock = "${fence}bash${nl}bash scripts/check-compose-rules.sh${nl}${fence}"
        $newBlock = "${fence}bash${nl}bash scripts/check-compose-rules.sh${nl}${fence}${nl}" +
            "Windows:${nl}" +
            "${fence}powershell${nl}" +
            "scripts\check-compose-rules.cmd${nl}${fence}"
        $content = $content.Replace($oldBlock, $newBlock)
    }

    return $content
}

Update-TextFile ".agents/rules/localization-rules.md" {
    param($content)

    $content = $content.Replace(
        '> Scripted checks run via [`check-localization-rules.sh`](../../scripts/check-localization-rules.sh).',
        '> Scripted checks run via [`check-localization-rules.sh`](../../scripts/check-localization-rules.sh) on Unix/Git Bash or [`check-localization-rules.cmd`](../../scripts/check-localization-rules.cmd) on Windows.'
    )

    return $content
}

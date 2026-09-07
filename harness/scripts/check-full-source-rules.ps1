param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Continue"
$python = Get-Command python3 -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command python -ErrorAction Stop
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
for ($index = 0; $index -lt $Arguments.Count; $index++) {
    switch ($Arguments[$index]) {
        "--project-root" {
            if ($index + 1 -ge $Arguments.Count) {
                Write-Host "ERROR: --project-root requires a path"
                exit 2
            }
            $index++
            if (-not (Test-Path -LiteralPath $Arguments[$index] -PathType Container)) {
                Write-Host "ERROR: project root does not exist: $($Arguments[$index])"
                exit 2
            }
            $projectRoot = (Resolve-Path -LiteralPath $Arguments[$index]).Path
        }
        "--help" {
            Write-Host "Usage: check-full-source-rules.ps1 [--project-root <path>]"
            exit 0
        }
        default {
            Write-Host "ERROR: unknown argument: $($Arguments[$index])"
            exit 2
        }
    }
}

$checker = Join-Path $PSScriptRoot "kotlin_ast_checker.py"
$checks = @(
    [pscustomobject]@{ Name = "Architecture rules (full source)"; Arguments = @("architecture", "--project-root", $projectRoot, "--all") },
    [pscustomobject]@{ Name = "Compose rules (full source)"; Arguments = @("compose", "--project-root", $projectRoot, "--all") },
    [pscustomobject]@{ Name = "Localization rules (full source)"; Arguments = @("localization", "--project-root", $projectRoot, "--all") },
    [pscustomobject]@{ Name = "Navigation rules (full source)"; Arguments = @("navigation", "--project-root", $projectRoot) },
    [pscustomobject]@{ Name = "Test assertion rules (full test source)"; Arguments = @("assertions", "--project-root", $projectRoot) }
)

$failed = $false
foreach ($check in $checks) {
    Write-Host ""
    Write-Host ">> $($check.Name)"
    & $python.Source $checker @($check.Arguments)
    $status = $LASTEXITCODE
    if ($status -eq 0) {
        Write-Host "PASS: $($check.Name)"
    } else {
        Write-Host "FAIL: $($check.Name) (exit $status)"
        $failed = $true
    }
}

if ($failed) {
    Write-Host "FAIL: full-source rules bundle (one or more checkers failed)"
    exit 1
}

Write-Host "PASS: full-source rules bundle (all checkers passed)"
exit 0

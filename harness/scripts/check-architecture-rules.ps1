param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"
$python = Get-Command python3 -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command python -ErrorAction Stop
}

& $python.Source (Join-Path $PSScriptRoot "kotlin_ast_checker.py") "architecture" @Arguments
exit $LASTEXITCODE

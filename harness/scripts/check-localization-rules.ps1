param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/rule-check-helpers.ps1"

$scanAll = $false
$sourceArg = $null
foreach ($argument in $Arguments) {
    if ($argument -eq "--all") {
        $scanAll = $true
    } elseif ($null -eq $sourceArg) {
        $sourceArg = $argument
    }
}

$projectRoot = Get-RuleCheckProjectRoot $PSScriptRoot
$sourceRoot = Resolve-RuleCheckSourceRoot $projectRoot $sourceArg
$ktFiles = @(Get-RuleCheckKotlinFiles $projectRoot $sourceRoot $scanAll)
$totalViolations = 0

Write-RuleCheckBanner "Localization Rules Checker" $sourceRoot $ktFiles.Count

Write-RuleCheckSection "1 - Hardcoded Strings in Text()"
Write-Host "  All user-visible text must use stringResource(), not raw string literals."
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Text() called with a raw string literal" '\bText\s*\(\s*"[^"]{1,}' $ktFiles

Write-RuleCheckSection "2 - Hardcoded Strings in Composable Parameters"
Write-Host "  label=, title=, placeholder=, hint= must not use raw string literals."
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Button/label/placeholder/hint set as a hardcoded string" '(label|title|placeholder|hint)\s*=\s*"[^"]' $ktFiles

Write-RuleCheckSection "3 - Hardcoded Local UI String Variables"
Write-Host "  Local variables holding UI labels must not be assigned raw string literals."
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Local UI label variable set as a hardcoded string" 'val\s+\w*(Label|Text|Title|Placeholder|Description|Action)\w*\s*=\s*"[^"]' $ktFiles

Write-RuleCheckSection "4 - Null contentDescription on Interactive Icons"
Write-Host "  Non-text interactive elements must have contentDescription = stringResource(...), not null."
$totalViolations += Invoke-RuleCheckRegex $projectRoot "contentDescription set to null" 'contentDescription\s*=\s*null' $ktFiles

Write-Host ""
Write-Host "======================================================"
if ($totalViolations -eq 0) {
    Write-Host "  OK All localization rules passed - 0 violations"
    Write-Host "======================================================"
    exit 0
}
Write-Host "  FAIL $totalViolations violation(s) found - see above"
Write-Host "======================================================"
exit 1

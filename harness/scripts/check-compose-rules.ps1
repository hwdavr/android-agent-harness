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

Write-RuleCheckBanner "Compose Rules Checker" $sourceRoot $ktFiles.Count

Write-RuleCheckSection "2 - Hardcoded Colors"
Write-Host "  Use LocalAppColors.current.<token>; AppColors.kt is excluded."
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Color(0x...) literal outside AppColors.kt" "Color\s*\(\s*0x[0-9A-Fa-f]+" $ktFiles @("AppColors.kt")
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Named Color constant outside AppColors.kt" "\bColor\.(Red|Green|Blue|Black|White|Gray|Grey|Yellow|Cyan|Magenta|Transparent|DarkGray|LightGray|Unspecified)\b" $ktFiles @("AppColors.kt")

Write-RuleCheckSection "2 - Missing testTag on Interactive Elements"
Write-Host "  Flags files with interactive elements but no testTag references."
Write-RuleCheckRule "Files containing interactive Composables but no testTag"
$noTagFiles = @()
foreach ($file in $ktFiles) {
    if ((Test-RuleCheckFileContains $file "\b(Button|FloatingActionButton|IconButton|Chip|Switch|Checkbox|RadioButton|Slider|DropdownMenu|ExposedDropdownMenuBox)\s*\(") -and
        -not (Test-RuleCheckFileContains $file "testTag")) {
        $noTagFiles += $file
    }
}
if ($noTagFiles.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($file in $noTagFiles) {
        Write-RuleCheckViolation (ConvertTo-RuleCheckRelativePath $projectRoot $file)
        $totalViolations++
    }
}

Write-RuleCheckSection "3 - ViewModel Inside Content Composables"
$totalViolations += Invoke-RuleCheckRegex $projectRoot "hiltViewModel() called inside a *Content composable" "fun\s+\w+Content\b[^{]*\{.*?hiltViewModel\s*\(" $ktFiles @() $true
$totalViolations += Invoke-RuleCheckRegex $projectRoot "viewModel() called inside a *Content composable" "fun\s+\w+Content\b[^{]*\{.*?\bviewModel\s*\(" $ktFiles @() $true

Write-RuleCheckSection "4 - Business Logic Inside Composables"
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Repository / UseCase call inside a @Composable function" "@Composable\b[^{]*fun\s+\w+[^{]*\{.*?(Repository|UseCase|DataSource)\s*\." $ktFiles @() $true

Write-RuleCheckSection "5 - Unstable testTag Values"
$totalViolations += Invoke-RuleCheckRegex $projectRoot "testTag with string interpolation" 'testTag\s*\(\s*"[^"]*\$\{?' $ktFiles
$totalViolations += Invoke-RuleCheckRegex $projectRoot "testTag with string concatenation or derived value" 'testTag\s*\(\s*("[^"]*"\s*\+|[A-Za-z_][A-Za-z0-9_]*\s*\+|[^)]*(lowercase|replace)\s*\()' $ktFiles

Write-RuleCheckSection "6 - Performance - Column + forEach Instead of LazyColumn"
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Column { ... .forEach { (use LazyColumn instead)" "Column\s*\{.*?\.forEach\s*\{" $ktFiles @() $true

Write-Host ""
Write-Host "======================================================"
if ($totalViolations -eq 0) {
    Write-Host "  OK All Compose rules passed - 0 violations"
    Write-Host "======================================================"
    exit 0
}
Write-Host "  FAIL $totalViolations violation(s) found - see above"
Write-Host "  Hint: run check-localization-rules for string resource violations"
Write-Host "======================================================"
exit 1

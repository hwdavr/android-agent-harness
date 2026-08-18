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

# Auto-detect base package: walk up to 4 levels to find the dir containing ui/, domain/, data/
# This avoids hard-coding the package name across different projects.
$basePkg = $null
$searchDirs = Get-ChildItem -Path $sourceRoot -Recurse -Depth 4 -Directory -ErrorAction SilentlyContinue | Sort-Object FullName
foreach ($dir in $searchDirs) {
    $hasUi     = Test-Path (Join-Path $dir.FullName "ui")
    $hasDomain = Test-Path (Join-Path $dir.FullName "domain")
    $hasData   = Test-Path (Join-Path $dir.FullName "data")
    if ($hasUi -or $hasDomain -or $hasData) {
        $basePkg = $dir.FullName
        break
    }
}
if ($null -eq $basePkg) { $basePkg = $sourceRoot }

$uiRoot = [System.IO.Path]::GetFullPath((Join-Path $basePkg "ui"))
$domainRoot = [System.IO.Path]::GetFullPath((Join-Path $basePkg "domain"))
$dataRoot = [System.IO.Path]::GetFullPath((Join-Path $basePkg "data"))
$ktFiles = @(Get-RuleCheckKotlinFiles $projectRoot $sourceRoot $scanAll)
$uiFiles = @($ktFiles | Where-Object { $_.StartsWith($uiRoot, [System.StringComparison]::OrdinalIgnoreCase) })
$domainFiles = @($ktFiles | Where-Object { $_.StartsWith($domainRoot, [System.StringComparison]::OrdinalIgnoreCase) })
$dataFiles = @($ktFiles | Where-Object { $_.StartsWith($dataRoot, [System.StringComparison]::OrdinalIgnoreCase) })
$viewModelFiles = @($ktFiles | Where-Object { $_ -match "[/\\]viewmodel[/\\]" })
$totalViolations = 0

Write-RuleCheckBanner "Architecture Rules Checker" $sourceRoot $ktFiles.Count
Write-Host "    UI files    : $($uiFiles.Count)"
Write-Host "    Domain files: $($domainFiles.Count)"
Write-Host "    Data files  : $($dataFiles.Count)"
Write-Host ""
Write-Host "  NOTE: Import-based layer boundary checks run via Detekt. Run './gradlew detekt'."

Write-RuleCheckSection "1 - UI Layer - Direct Data Access Inside Composable Bodies"
if ($uiFiles.Count -gt 0) {
    $totalViolations += Invoke-RuleCheckRegex $projectRoot "UI Composable calling Room DAO directly" "\bDao\b.*\.(get|insert|update|delete|query)\b" $uiFiles
    $totalViolations += Invoke-RuleCheckRegex $projectRoot "Composable calling repository or use case directly" "@Composable\b[^{]*fun\s+\w+[^{]*\{.*?(Repository|UseCase|DataSource)\s*\." $uiFiles @() $true
}

Write-RuleCheckSection "2 - Presentation Layer - Direct Retrofit Calls in ViewModel Bodies"
if ($viewModelFiles.Count -gt 0) {
    $totalViolations += Invoke-RuleCheckRegex $projectRoot "ViewModel calling Retrofit API service directly" "\bApiService\s*\.\s*(get|post|put|patch|delete|create|fetch|update)\b" $viewModelFiles
}

Write-RuleCheckSection "5 - State Management"
Write-RuleCheckRule "ViewModel with multiple StateFlow<Boolean> properties"
$boolFlowViolations = @()
foreach ($file in $viewModelFiles) {
    $count = ([regex]::Matches((Get-Content -Path $file -Raw), "StateFlow\s*<\s*Boolean\s*>")).Count
    if ($count -ge 3) {
        $boolFlowViolations += "$(ConvertTo-RuleCheckRelativePath $projectRoot $file) ($count StateFlow<Boolean>)"
    }
}
if ($boolFlowViolations.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $boolFlowViolations) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}
if ($viewModelFiles.Count -gt 0) {
    $totalViolations += Invoke-RuleCheckRegex $projectRoot "One-off event stored as a permanent UiState field" "val\s+(showDialog|showToast|showSnackbar|navigateTo|isNavigating|navigationEvent)\s*[=:]" $viewModelFiles
}

Write-RuleCheckSection "7 - Dependency Injection - Hilt Scoping"
if ($domainFiles.Count -gt 0) {
    $totalViolations += Invoke-RuleCheckRegex $projectRoot "Domain class receiving Context as constructor / inject parameter" "(fun\s+\w+|constructor)\s*\([^)]*\bContext\b" $domainFiles
}
Write-RuleCheckRule "RepositoryImpl missing @Singleton annotation"
$repoImplFiles = @($dataFiles | Where-Object { [System.IO.Path]::GetFileName($_) -like "*RepositoryImpl*" })
$missingSingleton = @()
foreach ($file in $repoImplFiles) {
    if (-not (Test-RuleCheckFileContains $file "@Singleton")) {
        $missingSingleton += ConvertTo-RuleCheckRelativePath $projectRoot $file
    }
}
if ($missingSingleton.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $missingSingleton) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-RuleCheckSection "8 - Forbidden Patterns"
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Fully-qualified class name used inline" "(?<!import )(com\.example\.\w+(\.\w+){3,}|io\.mockk\.\w+|retrofit2\.\w+|androidx\.\w+\.\w+)\s*[(<{]" $ktFiles @("build.gradle.kts")
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Direct Retrofit API call in ViewModel" "class\s+\w+ViewModel[^{]*\{.*?\.\s*(enqueue|execute|await)\s*\(" $ktFiles @() $true
$totalViolations += Invoke-RuleCheckRegex $projectRoot "Calculation / business logic branch inside @Composable" "@Composable\b[^{]*fun\s+\w+[^{]*\{.*?(when\s*\(\s*\w+\s*\)\s*\{|if\s*\([^)]*\.(status|state|type|role)\b)" $ktFiles @() $true

Write-RuleCheckRule "ViewModels missing a corresponding *Test.kt or *IntegrationTest.kt"
$testRoot = Join-Path $projectRoot "app/src/test"
$missingTests = @()
foreach ($file in $viewModelFiles) {
    $viewModelName = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $matches = @(Get-ChildItem -Path $testRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -eq "$viewModelName`Test.kt" -or $_.Name -eq "$viewModelName`IntegrationTest.kt"
    })
    if ($matches.Count -eq 0) {
        $missingTests += "$(ConvertTo-RuleCheckRelativePath $projectRoot $file) (no matching *Test.kt or *IntegrationTest.kt found)"
    }
}
if ($missingTests.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $missingTests) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-RuleCheckSection "9 - Package Structure - Misplaced Files"
Write-RuleCheckRule "ViewModel class files placed outside a viewmodel/ folder"
$vmMisplaced = @()
foreach ($file in $ktFiles) {
    if ((Test-RuleCheckFileContains $file "^\s*class\s+\w+ViewModel\b") -and $file -notmatch "[/\\]viewmodel[/\\]") {
        $vmMisplaced += ConvertTo-RuleCheckRelativePath $projectRoot $file
    }
}
if ($vmMisplaced.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $vmMisplaced) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-RuleCheckRule "UseCase class files placed outside a usecase/ folder"
$ucMisplaced = @()
foreach ($file in $ktFiles) {
    if ((Test-RuleCheckFileContains $file "^\s*class\s+\w+UseCase\b") -and $file -notmatch "[/\\]usecase[/\\]") {
        $ucMisplaced += ConvertTo-RuleCheckRelativePath $projectRoot $file
    }
}
if ($ucMisplaced.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $ucMisplaced) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-RuleCheckRule "RepositoryImpl class files placed outside data/repository/ folder"
$repoMisplaced = @()
foreach ($file in $ktFiles) {
    if ((Test-RuleCheckFileContains $file "^\s*class\s+\w+RepositoryImpl\b") -and -not $file.StartsWith((Join-Path $dataRoot "repository"), [System.StringComparison]::OrdinalIgnoreCase)) {
        $repoMisplaced += ConvertTo-RuleCheckRelativePath $projectRoot $file
    }
}
if ($repoMisplaced.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $repoMisplaced) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-RuleCheckRule "DTO-to-Domain mapper placed outside data/ layer"
$mapperViolations = @()
foreach ($file in $ktFiles) {
    if ([System.IO.Path]::GetFileName($file) -like "*Mapper*" -and $file.StartsWith($domainRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $mapperViolations += "$(ConvertTo-RuleCheckRelativePath $projectRoot $file) (mapper belongs in data/ or ui/, not domain/)"
    }
}
if ($mapperViolations.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $mapperViolations) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-RuleCheckSection "10 - Suppression Control"
Write-RuleCheckRule "New suppression / ignore directives added in this diff"
$suppressionPattern = "(@file:Suppress|@Suppress|@SuppressLint|tools:ignore|ktlint-disable|detekt-disable|noinspection|lint:ignore|baseline)"
$suppressionViolations = @()
Push-Location $projectRoot
try {
    $oldErrorActionPreference = $ErrorActionPreference
    $oldNativePreference = $null
    $hasNativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    if ($hasNativePreference) {
        $oldNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }
    $ErrorActionPreference = "Continue"
    & git rev-parse --is-inside-work-tree *> $null
    $insideGit = $LASTEXITCODE -eq 0
    if ($insideGit) {
        $diff = @(
            & git diff --unified=0 -- app/src app/build.gradle.kts build.gradle.kts detekt.yml .editorconfig 2>$null
            & git diff --cached --unified=0 -- app/src app/build.gradle.kts build.gradle.kts detekt.yml .editorconfig 2>$null
        )
        $lineNumber = 0
        foreach ($line in $diff) {
            $lineNumber++
            if ($line -match "^\+[^+]" -and $line -match $suppressionPattern) {
                $suppressionViolations += "${lineNumber}:$line"
            }
        }
    }
    if ($hasNativePreference) {
        $PSNativeCommandUseErrorActionPreference = $oldNativePreference
    }
    $ErrorActionPreference = $oldErrorActionPreference
} finally {
    Pop-Location
}
if ($suppressionViolations.Count -eq 0) {
    Write-RuleCheckNoViolations
} else {
    foreach ($violation in $suppressionViolations) {
        Write-RuleCheckViolation $violation
        $totalViolations++
    }
}

Write-Host ""
Write-Host "======================================================"
if ($totalViolations -eq 0) {
    Write-Host "  OK All architecture rules passed - 0 violations"
    Write-Host "======================================================"
    exit 0
}
Write-Host "  FAIL $totalViolations violation(s) found - see above"
Write-Host "======================================================"
exit 1

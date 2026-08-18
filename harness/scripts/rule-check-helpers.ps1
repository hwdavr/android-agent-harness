Set-StrictMode -Version Latest

function Get-RuleCheckProjectRoot {
    param([Parameter(Mandatory = $true)][string]$ScriptDirectory)
    return (Resolve-Path (Join-Path $ScriptDirectory "../..")).Path
}

function Resolve-RuleCheckSourceRoot {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$SourceRoot
    )
    if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
        $SourceRoot = Join-Path $ProjectRoot "app/src/main/java"
    }
    if ([System.IO.Path]::IsPathRooted($SourceRoot)) {
        return (Resolve-Path $SourceRoot).Path
    }
    return (Resolve-Path (Join-Path $ProjectRoot $SourceRoot)).Path
}

function ConvertTo-RuleCheckRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root += [System.IO.Path]::DirectorySeparatorChar
    }
    if ($fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($root.Length).Replace("\", "/")
    }
    return $fullPath.Replace("\", "/")
}

function Get-RuleCheckKotlinFiles {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [bool]$ScanAll
    )
    if ($ScanAll) {
        return @(Get-ChildItem -Path $SourceRoot -Recurse -Filter "*.kt" -File | ForEach-Object { $_.FullName })
    }

    $files = New-Object System.Collections.Generic.List[string]
    $insideGit = $false
    Push-Location $ProjectRoot
    $origEap = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        & git rev-parse --is-inside-work-tree *> $null
        $insideGit = $LASTEXITCODE -eq 0
        if ($insideGit) {
            $gitFiles = @(
                & git diff --name-only --diff-filter=d HEAD 2>$null
                & git diff --name-only --cached --diff-filter=d 2>$null
                & git ls-files --others --exclude-standard 2>$null
            )
            $ErrorActionPreference = $origEap
            foreach ($relativePath in ($gitFiles | Where-Object { $_ -match "\.kt$" } | Sort-Object -Unique)) {
                $fullPath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $relativePath))
                if ($fullPath.StartsWith($SourceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $fullPath)) {
                    $files.Add($fullPath)
                }
            }
        }
    } finally {
        $ErrorActionPreference = $origEap
        Pop-Location
    }

    if ($files.Count -eq 0) {
        return @(Get-ChildItem -Path $SourceRoot -Recurse -Filter "*.kt" -File | ForEach-Object { $_.FullName })
    }
    return @($files)
}

function Write-RuleCheckBanner {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [int]$FilesScanned = -1
    )
    Write-Host ""
    Write-Host "======================================================"
    Write-Host "  $Title - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "======================================================"
    Write-Host "  Source root: $SourceRoot"
    if ($FilesScanned -ge 0) {
        Write-Host "  Files scanned: $FilesScanned"
    }
    Write-Host ""
}

function Write-RuleCheckSection {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ""
    Write-Host ">> $Title"
}

function Write-RuleCheckRule {
    param([Parameter(Mandatory = $true)][string]$Rule)
    Write-Host "  Rule: $Rule"
}

function Write-RuleCheckNoViolations {
    Write-Host "    OK No violations"
}

function Write-RuleCheckViolation {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host "    $Text"
}

function Invoke-RuleCheckRegex {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$RuleName,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string[]]$Files,
        [string[]]$ExcludeFileNames = @(),
        [bool]$Singleline = $false
    )
    Write-RuleCheckRule $RuleName
    $violations = 0
    $options = [System.Text.RegularExpressions.RegexOptions]::None
    if ($Singleline) {
        $options = $options -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    }
    $regex = [System.Text.RegularExpressions.Regex]::new($Pattern, $options)
    foreach ($file in $Files) {
        if ($ExcludeFileNames -contains [System.IO.Path]::GetFileName($file)) {
            continue
        }
        if ($Singleline) {
            $content = Get-Content -Path $file -Raw
            $match = $regex.Match($content)
            if ($match.Success) {
                $line = ($content.Substring(0, $match.Index) -split "`r?`n").Count
                $text = $match.Value -replace "\s+", " "
                $relativePath = ConvertTo-RuleCheckRelativePath $ProjectRoot $file
                Write-RuleCheckViolation "${relativePath}:${line}:$text"
                $violations++
            }
        } else {
            $lineNumber = 0
            foreach ($line in Get-Content -Path $file) {
                $lineNumber++
                if ($regex.IsMatch($line)) {
                    $relativePath = ConvertTo-RuleCheckRelativePath $ProjectRoot $file
                    Write-RuleCheckViolation "${relativePath}:${lineNumber}:$line"
                    $violations++
                }
            }
        }
    }
    if ($violations -eq 0) {
        Write-RuleCheckNoViolations
    }
    return $violations
}

function Test-RuleCheckFileContains {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [bool]$Singleline = $false
    )
    $options = [System.Text.RegularExpressions.RegexOptions]::None
    if ($Singleline) {
        $options = $options -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    }
    $content = if ($Singleline) { Get-Content -Path $File -Raw } else { (Get-Content -Path $File) -join "`n" }
    return [System.Text.RegularExpressions.Regex]::IsMatch($content, $Pattern, $options)
}

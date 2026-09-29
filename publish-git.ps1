param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('major', 'feature', 'hotfix')]
    [string]$VersionType,

    [string]$Message = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Push-Location $projectRoot
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git was not found. Install Git and add it to PATH.'
    }

    $currentBranch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read the current Git branch.' }
    if ($currentBranch -ne 'main') {
        throw "Switch to main before publishing. Current branch: $currentBranch"
    }

    $changes = & git status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read the Git working tree.' }
    if (-not $changes) { throw 'There are no changes to publish.' }

    $pubspec = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'pubspec.yaml'))
    $versionMatch = [regex]::Match($pubspec, '(?m)^version:[ \t]*(\d+\.\d+\.\d+)\+\d+[ \t]*$')
    if (-not $versionMatch.Success) {
        throw 'Expected pubspec.yaml version format: major.minor.patch+build.'
    }

    $appVersion = $versionMatch.Groups[1].Value
    $branchName = "$VersionType/v$appVersion"
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = "$VersionType release v$appVersion"
    }

    & git show-ref --verify --quiet "refs/heads/$branchName"
    if ($LASTEXITCODE -eq 0) { throw "Local branch already exists: $branchName" }

    & git ls-remote --exit-code --heads origin $branchName *> $null
    if ($LASTEXITCODE -eq 0) { throw "Remote branch already exists: $branchName" }

    & git switch -c $branchName
    if ($LASTEXITCODE -ne 0) { throw "Unable to create branch: $branchName" }

    & git add -A
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stage the changes.' }

    & git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create the commit.' }

    & git push --set-upstream origin $branchName
    if ($LASTEXITCODE -ne 0) { throw "Unable to push branch: $branchName" }

    Write-Host "`nPublished branch: $branchName" -ForegroundColor Green
    Write-Host 'Create a Pull Request to merge it into main.' -ForegroundColor Cyan
} finally {
    Pop-Location
}

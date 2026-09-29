param(
    [ValidateSet('release', 'debug')]
    [string]$Mode = 'release',

    [ValidateSet('major', 'feature', 'hotfix')]
    [string]$VersionType = 'hotfix'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$preferredFlutter = 'C:\Users\month\develop\flutter\bin\flutter.bat'

if (Test-Path -LiteralPath $preferredFlutter) {
    $flutterExecutable = $preferredFlutter
} else {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -eq $flutterCommand) {
        throw 'Flutter SDK not found. Install Flutter 3.24+ or add its bin directory to PATH.'
    }
    $flutterExecutable = $flutterCommand.Source
}

Push-Location $projectRoot
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$originalPubspec = $null
$versionUpdated = $false
try {
    Write-Host "Using Flutter: $flutterExecutable" -ForegroundColor Cyan
    & $flutterExecutable --version
    if ($LASTEXITCODE -ne 0) { throw 'Unable to run the selected Flutter SDK.' }

    $originalPubspec = [System.IO.File]::ReadAllText($pubspecPath)
    $versionMatch = [regex]::Match($originalPubspec, '(?m)^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$')
    if (-not $versionMatch.Success) {
        throw 'Expected pubspec.yaml version format: major.minor.patch+build (for example 1.0.0+1).'
    }

    $major = [int]$versionMatch.Groups[1].Value
    $minor = [int]$versionMatch.Groups[2].Value
    $patch = [int]$versionMatch.Groups[3].Value
    $buildNumber = [int]$versionMatch.Groups[4].Value + 1

    switch ($VersionType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'feature' {
            $minor++
            $patch = 0
        }
        'hotfix' {
            $patch++
        }
    }

    $appVersion = "$major.$minor.$patch"
    $fullVersion = "$appVersion+$buildNumber"
    $updatedPubspec = $originalPubspec.Remove($versionMatch.Index, $versionMatch.Length).Insert(
        $versionMatch.Index,
        "version: $fullVersion"
    )
    [System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec)
    $versionUpdated = $true
    Write-Host "Version: $($versionMatch.Groups[1].Value).$($versionMatch.Groups[2].Value).$($versionMatch.Groups[3].Value)+$($versionMatch.Groups[4].Value) -> $fullVersion ($VersionType)" -ForegroundColor Yellow

    & $flutterExecutable pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    & $flutterExecutable build apk "--$Mode"
    if ($LASTEXITCODE -ne 0) { throw "Flutter $Mode APK build failed." }

    $flutterApkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$Mode.apk"
    if (-not (Test-Path -LiteralPath $flutterApkPath)) {
        throw "Build completed but Flutter APK was not found at $flutterApkPath"
    }

    $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\monthly-flow-$Mode-$appVersion.apk"
    Copy-Item -LiteralPath $flutterApkPath -Destination $apkPath -Force
    if (-not (Test-Path -LiteralPath $apkPath)) {
        throw "Unable to create the renamed APK at $apkPath"
    }

    $apk = Get-Item -LiteralPath $apkPath
    $sizeMb = [math]::Round($apk.Length / 1MB, 1)
    Write-Host "`nAPK ready: $($apk.FullName) ($sizeMb MB)" -ForegroundColor Green
} catch {
    if ($versionUpdated -and $null -ne $originalPubspec) {
        [System.IO.File]::WriteAllText($pubspecPath, $originalPubspec)
        Write-Warning 'Build failed. Restored the previous version in pubspec.yaml.'
    }
    throw
} finally {
    Pop-Location
}

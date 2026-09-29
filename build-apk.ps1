param(
    [ValidateSet('release', 'debug')]
    [string]$Mode = 'release'
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
try {
    Write-Host "Using Flutter: $flutterExecutable" -ForegroundColor Cyan
    & $flutterExecutable --version
    if ($LASTEXITCODE -ne 0) { throw 'Unable to run the selected Flutter SDK.' }

    & $flutterExecutable pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    & $flutterExecutable build apk "--$Mode"
    if ($LASTEXITCODE -ne 0) { throw "Flutter $Mode APK build failed." }

    $flutterApkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$Mode.apk"
    if (-not (Test-Path -LiteralPath $flutterApkPath)) {
        throw "Build completed but Flutter APK was not found at $flutterApkPath"
    }

    $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\monthly-flow-$Mode.apk"
    Copy-Item -LiteralPath $flutterApkPath -Destination $apkPath -Force
    if (-not (Test-Path -LiteralPath $apkPath)) {
        throw "Unable to create the renamed APK at $apkPath"
    }

    $apk = Get-Item -LiteralPath $apkPath
    $sizeMb = [math]::Round($apk.Length / 1MB, 1)
    Write-Host "`nAPK ready: $($apk.FullName) ($sizeMb MB)" -ForegroundColor Green
} finally {
    Pop-Location
}

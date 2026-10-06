param(
  [string]$SmtpHost,
  [int]$SmtpPort = 587,
  [string]$SmtpUser,
  [string]$FromAddress
)

$ErrorActionPreference = 'Stop'
$projectId = 'monthly-flow-75287'
$projectRoot = Split-Path -Parent $PSScriptRoot
$cliScript = Join-Path $projectRoot '.dart_tool\report-email-cli\node_modules\firebase-tools\lib\bin\firebase.js'

function Invoke-ReportFirebase {
  param([string[]]$CliArgs)
  & node $cliScript @CliArgs
  if ($LASTEXITCODE -ne 0) { throw 'Firebase command failed. Resolve the displayed error and run setup again.' }
}

Push-Location $projectRoot
try {
  if (!(Test-Path -LiteralPath $cliScript)) {
    & npm.cmd install --prefix .dart_tool/report-email-cli firebase-tools --ignore-scripts --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw 'Could not install Firebase CLI.' }
  }
  Invoke-ReportFirebase -CliArgs @('login')
  Invoke-ReportFirebase -CliArgs @('projects:list')
  Write-Host "Target project: $projectId"
  Write-Host 'The project needs Blaze billing for Cloud Functions. This script does not enable billing.'

  Push-Location (Join-Path $projectRoot 'functions')
  try {
    & npm.cmd ci --ignore-scripts
    if ($LASTEXITCODE -ne 0) { throw 'Could not install function dependencies.' }
    & npm.cmd test
    if ($LASTEXITCODE -ne 0) { throw 'Function tests failed.' }
  } finally { Pop-Location }

  if (!$SmtpHost) { $SmtpHost = Read-Host 'SMTP host' }
  if (!$SmtpUser) { $SmtpUser = Read-Host 'SMTP username' }
  if (!$FromAddress) { $FromAddress = Read-Host 'Verified sender email (From)' }
  if ($SmtpPort -notin @(465, 587) -or
      [string]::IsNullOrWhiteSpace($SmtpHost) -or
      [string]::IsNullOrWhiteSpace($SmtpUser) -or
      $FromAddress -notmatch '^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$') {
    throw 'Check SMTP host, port (465 or 587), username and sender email.'
  }
  $secretPassword = Read-Host 'SMTP password / SMTP key (hidden)' -AsSecureString
  $passwordPointer = [IntPtr]::Zero
  try {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretPassword)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ([string]::IsNullOrEmpty($plainPassword)) { throw 'SMTP password is required.' }
    $smtpJson = @{host=$SmtpHost; port=$SmtpPort; user=$SmtpUser;
      password=$plainPassword; from=$FromAddress} | ConvertTo-Json -Compress
    $plainPassword = $null
    $oldOutputEncoding = $OutputEncoding
    try {
      $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
      $smtpJson | & node (Join-Path $projectRoot 'functions\verify_smtp.js')
      if ($LASTEXITCODE -ne 0) { throw 'SMTP verification failed. Nothing was deployed.' }
      $smtpJson | & node $cliScript functions:secrets:set REPORT_SMTP_CONFIG --data-file - --project $projectId
      if ($LASTEXITCODE -ne 0) { throw 'Could not store SMTP settings in Secret Manager.' }
    } finally { $OutputEncoding = $oldOutputEncoding }
  } finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    $smtpJson = $null
    $plainPassword = $null
    $secretPassword.Dispose()
  }
  Invoke-ReportFirebase -CliArgs @('deploy', '--only', 'functions:report-email', '--project', $projectId)
  Write-Host 'Email service deployed. Restart the app and test Export > Account email.'
} finally { Pop-Location }

param(
  [string]$Device = "windows",
  [string]$ApiBaseUrl = "https://workhours.developerdomain.org",
  [string]$UpdateFeedUrl = "https://workhours.developerdomain.org/mobile-updates/latest.json",
  [string]$UpdatePageUrl = "https://workhours.developerdomain.org/mobile-updates/releases/latest",
  [switch]$SkipPubGet,
  [switch]$PrintCommandOnly
)

$ErrorActionPreference = "Stop"

function Resolve-FlutterCommand {
  $flutterFromPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($flutterFromPath) {
    return $flutterFromPath.Source
  }

  $localFlutter = "C:\Users\Carlo\tools\flutter-sdk\bin\flutter.bat"
  if (Test-Path $localFlutter) {
    return $localFlutter
  }

  throw "Flutter non trovato. Mettilo nel PATH oppure installalo in C:\Users\Carlo\tools\flutter-sdk\bin\flutter.bat"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$mobileDir = Join-Path $repoRoot "mobile"
$flutter = Resolve-FlutterCommand

$runArgs = @(
  "run",
  "-d",
  $Device,
  "--dart-define=API_BASE_URL=$ApiBaseUrl",
  "--dart-define=UPDATE_FEED_URL=$UpdateFeedUrl",
  "--dart-define=UPDATE_PAGE_URL=$UpdatePageUrl"
)

if ($PrintCommandOnly) {
  Write-Host "Flutter command:"
  Write-Host "$flutter $($runArgs -join ' ')"
  exit 0
}

Push-Location $mobileDir
try {
  if (-not $SkipPubGet) {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  }

  Write-Host ""
  Write-Host "Avvio client Flutter con hot reload su '$Device'..."
  Write-Host "API_BASE_URL=$ApiBaseUrl"
  Write-Host "UPDATE_FEED_URL=$UpdateFeedUrl"
  Write-Host ""
  Write-Host "Comandi utili nel terminale di flutter:"
  Write-Host "  r = hot reload"
  Write-Host "  R = hot restart"
  Write-Host "  q = chiudi"
  Write-Host ""

  & $flutter @runArgs
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}

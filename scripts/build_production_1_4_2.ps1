# Run this script in an interactive PowerShell terminal. It never accepts passwords as arguments.
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$keyDirectory = Join-Path $env:USERPROFILE '.android\kelasku'
$keystore = Join-Path $keyDirectory 'kelasku-release.p12'
$builtApk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$productionDirectory = Join-Path $projectRoot 'releases\production'
$productionApk = Join-Path $productionDirectory 'KelasKu-v1.4.2-production.apk'
$flutter = Join-Path $projectRoot '.tooling\flutter\bin\flutter.bat'
$apksigner = 'C:\Android\Sdk\build-tools\36.0.0\apksigner.bat'

if (-not (Test-Path -LiteralPath $flutter)) { throw 'Local Flutter installation not found.' }
if (-not (Test-Path -LiteralPath $apksigner)) { throw 'Android apksigner not found.' }
if (Test-Path -LiteralPath $productionApk) { throw 'Production APK already exists; it will not be overwritten.' }
if (-not (Test-Path -LiteralPath $keystore)) { throw 'Existing production keystore not found. No key will be created or replaced.' }

$securePassword = Read-Host 'Enter the permanent keystore password for this build' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$previousGradleOpts = $env:GRADLE_OPTS
try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ([string]::IsNullOrWhiteSpace($password)) { throw 'A nonempty keystore password is required.' }
    $env:KELASKU_RELEASE_KEYSTORE = $keystore
    $env:KELASKU_KEYSTORE_PASSWORD = $password
    $env:ANDROID_HOME = 'C:\Android\Sdk'
    $env:ANDROID_SDK_ROOT = 'C:\Android\Sdk'
    $env:ANDROID_USER_HOME = Join-Path $projectRoot '.tooling\android-user'
    $env:PUB_CACHE = Join-Path $projectRoot '.tooling\pub-cache'
    $env:GRADLE_USER_HOME = Join-Path $projectRoot '.tooling\gradle'
    $env:GRADLE_OPTS = "$previousGradleOpts -Dorg.gradle.daemon=false".Trim()
    Push-Location $projectRoot
    try {
        & $flutter build apk --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item Env:\KELASKU_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:\KELASKU_RELEASE_KEYSTORE -ErrorAction SilentlyContinue
    $env:GRADLE_OPTS = $previousGradleOpts
    $password = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $securePassword.Dispose()
}

if (-not (Test-Path -LiteralPath $builtApk)) { throw 'Flutter did not produce an APK.' }
$signature = & $apksigner verify --print-certs $builtApk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
if (-not ($signature -match '500b34efbb470855b3fbb9ec721eeb2a1be9af0e2d4fdb979d10b9b46889bda1')) {
    throw 'The APK does not use the existing KelasKu production certificate. No artifact was copied.'
}
New-Item -ItemType Directory -Path $productionDirectory -Force | Out-Null
Copy-Item -LiteralPath $builtApk -Destination $productionApk
Write-Host "Production APK: $productionApk"
Get-FileHash -LiteralPath $productionApk -Algorithm SHA256 | Select-Object Hash

<#
.SYNOPSIS
    Updates civic-gads and any cloned client libraries on Windows.

.DESCRIPTION
    1. Backs up customer_id.txt and .claude\settings.json (if locally modified).
    2. git pull on the project repo.
    3. Restores user customizations.
    4. Optionally clones additional client libraries (-Php, -Ruby, -Java, -Dotnet).
    5. git pull on every existing client_libs\<repo>\.
#>

param(
    [switch]$Python,
    [switch]$Php,
    [switch]$Ruby,
    [switch]$Java,
    [switch]$Dotnet
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: git is not installed."
    exit 1
}

try {
    $ProjectDirAbs = git rev-parse --show-toplevel 2>$null
    if (-not $ProjectDirAbs) { throw "Not in a git repo" }
    $ProjectDirAbs = (Get-Item -LiteralPath $ProjectDirAbs).FullName
}
catch {
    Write-Error "ERROR: Run this from inside the civic-gads git repository."
    exit 1
}
Write-Host "Detected project root: $ProjectDirAbs"

$SettingsJson    = Join-Path $ProjectDirAbs ".claude\settings.json"
$CustomerIdFile  = Join-Path $ProjectDirAbs "customer_id.txt"
$TempSettings    = New-TemporaryFile
$TempCustomerId  = New-TemporaryFile

function Backup-And-Reset {
    param([string]$File, [string]$Tmp)
    if (Test-Path $File) {
        Copy-Item -LiteralPath $File -Destination $Tmp -Force
        $tracked = git ls-files --error-unmatch $File 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Resetting $File to avoid merge conflicts..."
            git checkout $File | Out-Null
        }
    }
}

Backup-And-Reset -File $SettingsJson   -Tmp $TempSettings
Backup-And-Reset -File $CustomerIdFile -Tmp $TempCustomerId

Write-Host "Updating civic-gads..."
git pull
if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: git pull failed."
    if ((Get-Item $TempSettings).Length   -gt 0) { Move-Item -Force $TempSettings   $SettingsJson }
    if ((Get-Item $TempCustomerId).Length -gt 0) { Move-Item -Force $TempCustomerId $CustomerIdFile }
    exit 1
}

if ((Get-Item $TempSettings).Length -gt 0) {
    Write-Host "Restoring local settings.json (overrides repo defaults)."
    Move-Item -Force $TempSettings $SettingsJson
} else {
    Remove-Item -Force $TempSettings
}
if ((Get-Item $TempCustomerId).Length -gt 0) {
    Write-Host "Restoring local customer_id.txt."
    Move-Item -Force $TempCustomerId $CustomerIdFile
} else {
    Remove-Item -Force $TempCustomerId
}

$ClientLibsDir = Join-Path $ProjectDirAbs "client_libs"
New-Item -ItemType Directory -Force -Path $ClientLibsDir | Out-Null

$Repos = @{
    python = @{ url = "https://github.com/googleads/google-ads-python.git"; name = "google-ads-python" }
    php    = @{ url = "https://github.com/googleads/google-ads-php.git";    name = "google-ads-php" }
    ruby   = @{ url = "https://github.com/googleads/google-ads-ruby.git";   name = "google-ads-ruby" }
    java   = @{ url = "https://github.com/googleads/google-ads-java.git";   name = "google-ads-java" }
    dotnet = @{ url = "https://github.com/googleads/google-ads-dotnet.git"; name = "google-ads-dotnet" }
}

$Requested = @()
if ($Python) { $Requested += "python" }
if ($Php)    { $Requested += "php" }
if ($Ruby)   { $Requested += "ruby" }
if ($Java)   { $Requested += "java" }
if ($Dotnet) { $Requested += "dotnet" }

foreach ($lang in $Requested) {
    $info = $Repos[$lang]
    $libPath = Join-Path $ClientLibsDir $info.name
    if (-not (Test-Path $libPath)) {
        Write-Host "Cloning $($info.name)..."
        git clone $info.url $libPath
        if ($LASTEXITCODE -ne 0) { Write-Error "ERROR: clone failed for $($info.url)"; exit 1 }
    }
}

Write-Host "Updating client libraries under $ClientLibsDir..."
Get-ChildItem -Directory $ClientLibsDir | ForEach-Object {
    if (Test-Path (Join-Path $_.FullName ".git")) {
        Write-Host "Updating $($_.FullName)..."
        Push-Location $_.FullName
        try { git pull } finally { Pop-Location }
    }
}

Write-Host "Update complete."

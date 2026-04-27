<#
.SYNOPSIS
    Initializes the development environment for civic-gads on Windows.

.DESCRIPTION
    Clones or updates the selected Google Ads client libraries into client_libs/
    so the agent can Grep/Read them locally. No settings file mutation is
    required; Claude Code reads everything inside the project directory.

.PARAMETER Php
    Include google-ads-php.

.PARAMETER Ruby
    Include google-ads-ruby.

.PARAMETER Java
    Include google-ads-java.

.PARAMETER Dotnet
    Include google-ads-dotnet.

.EXAMPLE
    .\install.ps1 -Java
    Installs Java and Python libraries.

.EXAMPLE
    .\install.ps1
    Installs only the Python library.
#>

param(
    [switch]$Php,
    [switch]$Ruby,
    [switch]$Java,
    [switch]$Dotnet
)

$ErrorActionPreference = "Stop"

try {
    $ProjectDirAbs = git rev-parse --show-toplevel 2>$null
    if (-not $ProjectDirAbs) { throw "Not in a git repo" }
    $ProjectDirAbs = (Get-Item -LiteralPath $ProjectDirAbs).FullName
}
catch {
    Write-Error "ERROR: This script must be run from within the civic-gads git repository."
    exit 1
}
Write-Host "Detected project root: $ProjectDirAbs"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: git is not installed."
    exit 1
}

$ClientLibsDir = Join-Path $ProjectDirAbs "client_libs"
New-Item -ItemType Directory -Force -Path $ClientLibsDir | Out-Null

# Repo registry
$Repos = @{
    python = @{ url = "https://github.com/googleads/google-ads-python.git"; name = "google-ads-python" }
    php    = @{ url = "https://github.com/googleads/google-ads-php.git";    name = "google-ads-php" }
    ruby   = @{ url = "https://github.com/googleads/google-ads-ruby.git";   name = "google-ads-ruby" }
    java   = @{ url = "https://github.com/googleads/google-ads-java.git";   name = "google-ads-java" }
    dotnet = @{ url = "https://github.com/googleads/google-ads-dotnet.git"; name = "google-ads-dotnet" }
}

# Python is always installed.
$Selected = @("python")
if ($Php)    { $Selected += "php" }
if ($Ruby)   { $Selected += "ruby" }
if ($Java)   { $Selected += "java" }
if ($Dotnet) { $Selected += "dotnet" }

if ($Selected.Count -eq 1) {
    Write-Host "No additional languages selected. Defaulting to Python only."
}

function Clone-OrUpdate {
    param([string]$RepoUrl, [string]$ClonePath)
    $RepoName = Split-Path $ClonePath -Leaf
    Write-Host "Managing repository $RepoName in $ClonePath"
    if (Test-Path (Join-Path $ClonePath ".git")) {
        Write-Host "Updating $RepoName..."
        Push-Location $ClonePath
        try { git pull } finally { Pop-Location }
    }
    elseif (Test-Path $ClonePath) {
        Write-Warning "Directory $ClonePath exists but is not a git repo. Skipping."
    }
    else {
        Write-Host "Cloning $RepoUrl into $ClonePath"
        git clone $RepoUrl $ClonePath
        if ($LASTEXITCODE -ne 0) { Write-Error "ERROR: Failed to clone $RepoUrl"; exit 1 }
    }
}

foreach ($lang in $Selected) {
    $info = $Repos[$lang]
    Clone-OrUpdate -RepoUrl $info.url -ClonePath (Join-Path $ClientLibsDir $info.name)
}

Write-Host ""
Write-Host "civic-gads installation complete."
Write-Host "Cloned client libraries are under: $ClientLibsDir"
Write-Host "The agent will Grep/Read them locally - no settings changes required."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Ensure %USERPROFILE%\google-ads.yaml exists with valid credentials."
Write-Host "  2. Open this directory in Claude Code: cd `"$ProjectDirAbs`"; claude"
Write-Host "  3. The SessionStart hook will create .venv\\, install google-ads + ruff,"
Write-Host "     and copy your credentials into .\config\."

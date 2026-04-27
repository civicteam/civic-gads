<#
.SYNOPSIS
    Removes the local civic-gads project directory.
#>

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

Write-Host "This will DELETE the entire directory: $ProjectDirAbs"
$confirm = Read-Host "Are you sure you want to proceed? (Y/n)"
if ($confirm -notmatch '^[Yy]$') {
    Write-Host "Uninstallation cancelled."
    exit 0
}

Write-Host "Removing project directory: $ProjectDirAbs..."
$parent = Split-Path -Parent $ProjectDirAbs
$name   = Split-Path -Leaf   $ProjectDirAbs
Set-Location $parent
Remove-Item -Recurse -Force $name

Write-Host "Uninstallation complete."

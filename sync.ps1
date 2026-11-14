<#
.SYNOPSIS
    Syncs custom skills to the local Antigravity global skills directory (~/.gemini/config/skills).
#>
$Source = Join-Path $PSScriptRoot "skills"
$Destination = Join-Path $env:USERPROFILE ".gemini\config\skills"

if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

Copy-Item -Path "$Source\*" -Destination $Destination -Recurse -Force
Write-Host "✓ Successfully synced skills from $Source to $Destination" -ForegroundColor Green

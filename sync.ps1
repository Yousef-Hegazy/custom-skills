<#
.SYNOPSIS
    Syncs custom skills to the local Antigravity global skills directory (~/.gemini/config/skills).
#>
$Source = Join-Path $PSScriptRoot "skills"
$Destination = Join-Path $env:USERPROFILE ".gemini\config\skills"

# Sidelined skills excluded from global sync until re-enabled
$ExcludedSkills = @("opus-rigor")

if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

Get-ChildItem -Path $Source -Directory | Where-Object { $_.Name -notin $ExcludedSkills } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $Destination -Recurse -Force
}

Write-Host "✓ Successfully synced active skills from $Source to $Destination" -ForegroundColor Green
if ($ExcludedSkills.Count -gt 0) {
    Write-Host "  (Excluded: $($ExcludedSkills -join ', '))" -ForegroundColor Yellow
}

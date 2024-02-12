# Common settings - use this in all scripts by sourcing: `. ./tools/settings.ps1`
Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Enable debug logging in CI
if (Test-Path env:CI)
{
    $DebugPreference = 'Continue'
}

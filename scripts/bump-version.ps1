param([string] $newVersion)

. "$PSScriptRoot/settings.ps1"

$parts = $newVersion -split '-'
if ($parts.Length -eq 1) {
    $version = $parts[0]
    $prerelease = ''
} elseif ($parts.Length -eq 2) {
    <# Action when this condition is true #>
    $version = $parts[0]
    $prerelease = $parts[1]
} else {
    throw "Invalid version format: $newVersion"
}

$moduleFile = "$PSScriptRoot/../modules/Sentry/Sentry.psd1"
$content = Get-Content $moduleFile
$changes = 0
for ($i = 0; $i -lt $content.Length; $i++) {
    if ($content[$i] -match "^(\s*ModuleVersion\s*=\s*)'[^']*'\s*$") {
        $content[$i] = $matches[1] + "'$version'"
        $changes++
    }
    if ($content[$i] -match "^(\s*Prerelease\s*=\s*)'[^']*'\s*$") {
        $content[$i] = $matches[1] + "'$prerelease'"
        $changes++
    }
}

if ($changes -ne 2) {
    throw "Failed to update version in $moduleFile"
}

$content | Out-File $moduleFile

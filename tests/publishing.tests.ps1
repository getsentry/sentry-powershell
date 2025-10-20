Describe 'Publishing' {
    It 'Test-ModuleManifest' {
        Test-ModuleManifest -Path "$PSScriptRoot/../modules/Sentry/Sentry.psd1" -Verbose
    }

    It 'Publish-Module' {
        $tempModuleDir = "$PSScriptRoot/temp/Sentry"
        Remove-Item $tempModuleDir -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item "$PSScriptRoot/../modules/Sentry" -Destination $tempModuleDir -Recurse

        # Update version in the module manifest
        $content = Get-Content "$tempModuleDir/Sentry.psd1"
        $changes = 0
        for ($i = 0; $i -lt $content.Length; $i++)
        {
            if ($content[$i] -match "^(\s*ModuleVersion\s*=\s*)'[^']*'\s*$")
            {
                $content[$i] = $matches[1] + "'9.9.9'"
                $changes++
            }
            if ($content[$i] -match "^(\s*Prerelease\s*=\s*)'[^']*'\s*$")
            {
                $content[$i] = $matches[1] + "'test'"
                $changes++
            }
        }
        $changes | Should -Be 2
        $content | Out-File "$tempModuleDir/Sentry.psd1"

        Publish-Module -Path $tempModuleDir -NuGetApiKey 'test' -Verbose -WhatIf
    }
}

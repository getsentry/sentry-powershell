BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    StartSentryForEventTests ([ref] $events)
    $versionRegex = '^\d+\.\d+\.\d+(.\d+)?(-.*)?$'
}

AfterAll {
    Stop-Sentry
}

Describe 'Out-Sentry for <_>' -ForEach @('message', 'error') {
    BeforeEach {
        $param = $_
        if ($param -eq 'error')
        {
            try
            {
                throw 'error'
            }
            catch
            {
                $_ | Out-Sentry
            }
        }
        else
        {
            $param | Out-Sentry
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
    }

    AfterEach {
        $events.Clear()
    }

    It 'Sets SDK info' {
        $event.Sdk.Name | Should -Be 'sentry.powershell'
        $event.Sdk.Version | Should -Match $versionRegex
    }

    It 'Sets .NET SDK as a package' {
        $package = $event.Sdk.Packages | Where-Object -Property Name -EQ 'nuget:sentry.dotnet'
        $package.Version | Should -Match $versionRegex
    }

    It 'Sets PowerShell SDK as a package' {
        $package = $event.Sdk.Packages | Where-Object -Property Name -EQ "ps:$($event.Sdk.Name)"
        $package.Version | Should -Match $event.Sdk.Version
    }

    It 'Sets PS modules as modules' {
        $pesterModule = Get-Module -Name 'Pester'
        $event.Modules['Pester'] | Should -Be $pesterModule.Version.ToString()
    }

    It 'Sets PowerShell as the platform' {
        $event.Platform | Should -Be 'powershell'
    }

    It 'Sets .NET modules present in stack traces as modules' {
        $event.Modules['System.Management.Automation'] | Should -Match $versionRegex
    }

    It 'Sets PowerShell as runtime' {
        if ($PSVersionTable.PSVersion.Major -eq 5)
        {
            $event.Contexts.Runtime.Name | Should -Be 'Windows PowerShell'
        }
        else
        {
            $event.Contexts.Runtime.Name | Should -Be 'PowerShell'
        }
        $event.Contexts.Runtime.Version | Should -Be $PSVersionTable.PSVersion.ToString()
    }

    It 'Sets .NET as runtime' {
        $event.Contexts['runtime.net'].Name | Should -Not -BeNullOrEmpty
        $event.Contexts['runtime.net'].Version | Should -Match $versionRegex
    }

    It 'Does not set release automatically' {
        $event.Release | Should -BeNullOrEmpty
    }
}

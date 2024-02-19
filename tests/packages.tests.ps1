BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    StartSentryForEventTests ([ref] $events)
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
        $event.Sdk.Version | Should -Match '^\d+\.\d+\.\d+$'
    }

    It 'Sets .NET SDK as a package' {
        $package = $event.Sdk.Packages | Where-Object -Property Name -EQ 'nuget:sentry.dotnet'
        $package.Version | Should -Match '^\d+\.\d+\.\d+$'
    }

    It 'Sets PowerShell SDK as a package' {
        $package = $event.Sdk.Packages | Where-Object -Property Name -EQ "ps:$($event.Sdk.Name)"
        $package.Version | Should -Match $event.Sdk.Version
    }

    It 'Sets PS modules as modules' {
        $pesterModule = Get-Module -Name 'Pester'
        $event.Modules['Pester'] | Should -Be $pesterModule.Version.ToString()
        $event.Modules.Count | Should -Be 1
    }

    It 'Sets powershell as the platform' {
        $event.Platform | Should -Be 'powershell'
    }
}

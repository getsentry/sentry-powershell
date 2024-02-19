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
        $package = $event.Sdk.Packages | Where-Object -Property Name -EQ 'ps:Sentry'
        $package.Version | Should -Match $event.Sdk.Version
    }

    It 'Sets PS modules as packages' {
        $pesterModule = Get-Module -Name 'Pester'
        $package = $event.Sdk.Packages | Where-Object -Property Name -EQ "ps:$($pesterModule.Name)"
        $package.Version | Should -Be $pesterModule.Version.ToString()
    }

    It 'Sets powershell as the platform' {
        $event.Platform | Should -Be 'powershell'
    }
}

BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    StartSentryForEventTests ([ref] $events)
}

AfterAll {
    Stop-Sentry
}

Describe 'Out-Sentry' {
    AfterEach {
        $events.Clear()
    }

    It 'Sets SDK info' {
        'Message' | Out-Sentry

        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.Sdk.Name | Should -Be 'sentry.powershell'
        $event.Sdk.Version | Should -Match '^\d+\.\d+\.\d+$'

        $packages = $event.Sdk.Packages.ToArray()
        $packages.Count | Should -BeGreaterThan 1
        $packages[0].Name | Should -Be 'nuget:sentry.dotnet'
        $packages[0].Version | Should -Match '^\d+\.\d+\.\d+$'
        $packages[1].Name | Should -Be 'ps:Sentry'
        $packages[1].Version | Should -Be $event.Sdk.Version
    }
}

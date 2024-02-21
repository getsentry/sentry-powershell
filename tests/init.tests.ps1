BeforeAll {
    . $PSScriptRoot/utils.ps1
}

Describe 'SentrySdk' {
    AfterEach {
        Stop-Sentry
    }

    It 'type exists' {
        [Sentry.SentrySdk].GetType().Name | Should -Be 'RuntimeType'
    }

    It 'init starts the SDK' {
        $handle = [Sentry.SentrySdk]::init('https://key@host/1')
        $handle | Should -Be Sentry.SentrySdk+DisposeHandle
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true
    }

    It 'close closes the SDK' {
        $handle = [Sentry.SentrySdk]::init('https://key@host/1')
        $handle | Should -Be Sentry.SentrySdk+DisposeHandle
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true
        Stop-Sentry
        [Sentry.SentrySdk]::IsEnabled | Should -Be $false
    }

    It 'Start-Sentry starts the SDK' {
        Start-Sentry 'https://key@host/1'
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true
    }

    It 'Stop-Sentry closes the SDK' {
        Start-Sentry 'https://key@host/1'
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true
        Stop-Sentry
        [Sentry.SentrySdk]::IsEnabled | Should -Be $false
    }

    It 'Start-Sentry respects options' {
        $testIntegration = [TestIntegration]::new()
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            [Sentry.sentryOptionsExtensions]::AddIntegration($_, $testIntegration)
        }
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true
        $testIntegration.Options | Should -BeOfType [Sentry.SentryOptions]
        $testIntegration.Hub | Should -Not -Be $null

        Stop-Sentry
    }

    It 'Start-Sentry sets Debug based on DebugPreference (<_>)' -ForEach @($true, $false) {
        $value = $_
        $originalValue = $global:DebugPreference
        if ($value)
        {
            $global:DebugPreference = 'Continue'
        }
        else
        {
            $global:DebugPreference = 'SilentlyContinue'
        }
        try
        {
            Start-Sentry {
                $_.Dsn = 'https://key@127.0.0.1/1'
                $_.Debug | Should -Be $value
            }
        }
        finally
        {
            $global:DebugPreference = $originalValue
        }
    }

    It 'Start-Sentry sets Debug based on Debug automatic parameter' -ForEach @($true, $false) {
        $value = $_
        Start-Sentry -Debug:$_ {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.Debug | Should -Be $value
        }
    }

    It 'Start-Sentry sets the expected default options' {
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.IsGlobalModeEnabled | Should -Be $true
            $_.ReportAssembliesMode | Should -Be 'None'
        }
    }

    It 'Out-Sentry does not crash when Sentry is not enabled' {
        'message' | Out-Sentry -Debug
    }

    It 'Out-Sentry does not capture when Sentry is not enabled' {
        $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
        StartSentryForEventTests ([ref] $events)
        Stop-Sentry
        'message' | Out-Sentry -Debug
        $events.Count | Should -Be 0
    }
}

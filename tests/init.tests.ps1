BeforeAll {
    . $PSScriptRoot/utils.ps1
}

Describe 'SentrySdk' {
    AfterEach {
        [Sentry.SentrySdk]::close()
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
        [Sentry.SentrySdk]::close()
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
        $options = [Sentry.SentryOptions]::new()
        $options.Debug = $true
        $options.Dsn = 'https://key@127.0.0.1/1'
        $testIntegration = [TestIntegration]::new()
        [Sentry.sentryOptionsExtensions]::AddIntegration($options, $testIntegration)

        Start-Sentry $options
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true
        $testIntegration.Options | Should -Be $options
        $testIntegration.Hub | Should -Not -Be $null

        [Sentry.SentrySdk]::close()
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
            $options = [Sentry.SentryOptions]::new()
            $options.Dsn = 'https://key@127.0.0.1/1'
            $options.Debug | Should -Be $false
            Start-Sentry $options
            $options.Debug | Should -Be $value
        }
        finally
        {
            $global:DebugPreference = $originalValue
        }
    }

    It 'Start-Sentry sets Debug based on Debug automatic parameter' -ForEach @($true, $false) {
        $value = $_
        $options = [Sentry.SentryOptions]::new()
        $options.Dsn = 'https://key@127.0.0.1/1'
        $options.Debug | Should -Be $false
        Start-Sentry $options -Debug:$_
        $options.Debug | Should -Be $value
    }
}

BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $global:SentryPowershellRethrowErrors = $true

    function StartSentryForLogTests {
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.Experimental.EnableLogs = $true
            $_.Experimental.SetBeforeSendLog([System.Func[Sentry.SentryLog, Sentry.SentryLog]] {
                    param([Sentry.SentryLog]$log)
                    $script:logs.Add($log)
                    return $null
                })
            $_.Transport = [RecordingTransport]::new()
        }
    }

    # Logs go through a background batch processor; flush before asserting.
    function FlushLogs { [Sentry.SentrySdk]::Flush([TimeSpan]::FromSeconds(5)) | Out-Null }
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
}

Describe 'Write-SentryLog' {
    BeforeEach {
        $script:logs = [System.Collections.Generic.List[Sentry.SentryLog]]::new()
        StartSentryForLogTests
    }

    AfterEach {
        Stop-Sentry
    }

    It 'sends an Info log by default' {
        Write-SentryLog 'hello'
        FlushLogs

        $script:logs.Count | Should -Be 1
        $script:logs[0].Level | Should -Be ([Sentry.SentryLogLevel]::Info)
        $script:logs[0].Message | Should -Be 'hello'
        $script:logs[0].Template | Should -Be 'hello'
    }

    It 'accepts the message from the pipeline' {
        'piped message' | Write-SentryLog -Level Warning
        FlushLogs

        $script:logs.Count | Should -Be 1
        $script:logs[0].Level | Should -Be ([Sentry.SentryLogLevel]::Warning)
        $script:logs[0].Message | Should -Be 'piped message'
    }

    It 'sends a log at each supported level' {
        Write-SentryLog -Level Trace 'trace'
        Write-SentryLog -Level Debug 'debug'
        Write-SentryLog -Level Info 'info'
        Write-SentryLog -Level Warning 'warning'
        Write-SentryLog -Level Error 'error'
        Write-SentryLog -Level Fatal 'fatal'
        FlushLogs

        $script:logs.Count | Should -Be 6
        $script:logs[0].Level | Should -Be ([Sentry.SentryLogLevel]::Trace)
        $script:logs[1].Level | Should -Be ([Sentry.SentryLogLevel]::Debug)
        $script:logs[2].Level | Should -Be ([Sentry.SentryLogLevel]::Info)
        $script:logs[3].Level | Should -Be ([Sentry.SentryLogLevel]::Warning)
        $script:logs[4].Level | Should -Be ([Sentry.SentryLogLevel]::Error)
        $script:logs[5].Level | Should -Be ([Sentry.SentryLogLevel]::Fatal)
    }

    It 'substitutes parameters into the template' {
        Write-SentryLog -Level Info -Message 'User {0} ran {1}' -Parameters 'alice', 'send-logs.ps1'
        FlushLogs

        $script:logs.Count | Should -Be 1
        $script:logs[0].Template | Should -Be 'User {0} ran {1}'
        $script:logs[0].Message | Should -Be 'User alice ran send-logs.ps1'
        $script:logs[0].Parameters.Length | Should -Be 2
    }

    It 'attaches structured attributes' {
        Write-SentryLog -Level Error -Message 'oops' -Attributes @{ user = 'bob'; retries = 3 }
        FlushLogs

        $script:logs.Count | Should -Be 1
        $userValue = $null
        $script:logs[0].TryGetAttribute('user', [ref] $userValue) | Should -Be $true
        $userValue | Should -Be 'bob'
        $retriesValue = $null
        $script:logs[0].TryGetAttribute('retries', [ref] $retriesValue) | Should -Be $true
        $retriesValue | Should -Be 3
    }

    It 'combines parameters and attributes in a single call' {
        Write-SentryLog -Level Warning `
            -Message 'host {0} is at {1}%' `
            -Parameters 'web-1', 92 `
            -Attributes @{ region = 'us-east-1' }
        FlushLogs

        $script:logs.Count | Should -Be 1
        $script:logs[0].Message | Should -Be 'host web-1 is at 92%'
        $script:logs[0].Parameters.Length | Should -Be 2
        $regionValue = $null
        $script:logs[0].TryGetAttribute('region', [ref] $regionValue) | Should -Be $true
        $regionValue | Should -Be 'us-east-1'
    }
}

Describe 'Write-SentryLog when Sentry is not started' {
    It 'is a no-op and does not throw' {
        [Sentry.SentrySdk]::IsEnabled | Should -Be $false
        { Write-SentryLog -Level Info 'should be ignored' } | Should -Not -Throw
    }
}

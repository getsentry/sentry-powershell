Describe 'SentrySdk' {
    It 'init respects options' {
        class TestLogger:Sentry.Infrastructure.DiagnosticLogger
        {
            TestLogger([Sentry.SentryLevel]$level) : base($level) {}

            $entries = [System.Collections.Concurrent.ConcurrentQueue[string]]::new();

            [void]LogMessage([string] $message) { $this.entries.Enqueue($message); }
        }

        $logger = [TestLogger]::new([Sentry.SentryLevel]::Debug)

        $options = [Sentry.SentryOptions]::new()
        $options.Debug = $true
        $options.Dsn = 'https://key@127.0.0.1/1'
        $options.DiagnosticLogger = $logger
        [Sentry.SentrySdk]::init($options)
        [Sentry.SentrySdk]::IsEnabled | Should -Be $true

        $logger.entries.Count | Should -BeGreaterThan 0
        [Sentry.SentrySdk]::close()
    }
}

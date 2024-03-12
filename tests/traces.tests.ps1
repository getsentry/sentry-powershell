AfterAll {
    Stop-Sentry
}

Describe 'Start-SentryTransaction' {
    It 'sets custom context from a hashmap' {
        $global:TraceSamplerExecuted = $false
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.TracesSampler = [System.Func[Sentry.TransactionSamplingContext, System.Nullable`1[System.Double]]] {
                param([Sentry.TransactionSamplingContext]$context)

                $context.TransactionContext | Should -Not -Be $null
                $context.TransactionContext.Name | Should -Be 'foo'
                $context.TransactionContext.Operation | Should -Be 'bar'
                $context.TransactionContext.Description | Should -BeNullOrEmpty
                $context.CustomSamplingContext | Should -Not -Be $null
                $context.CustomSamplingContext['user_id'] | Should -Be 42
                $context.CustomSamplingContext['search_results'] | Should -BeOfType [hashtable]
                $context.CustomSamplingContext['nullable'] | Should -Be $null
                $global:TraceSamplerExecuted = $true
            }
        }

        $transaction = Start-SentryTransaction 'foo' 'bar' @{
            'user_id'        = 42
            'search_results' = @{}
            'nullable'       = $null
        }

        $global:TraceSamplerExecuted | Should -Be $true
    }
    It 'sets custom context from a hashmap when description is present' {
        $global:TraceSamplerExecuted = $false
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.TracesSampler = [System.Func[Sentry.TransactionSamplingContext, System.Nullable`1[System.Double]]] {
                param([Sentry.TransactionSamplingContext]$context)

                $context.TransactionContext | Should -Not -Be $null
                $context.TransactionContext.Name | Should -Be 'foo'
                $context.TransactionContext.Operation | Should -Be 'bar'
                $context.TransactionContext.Description | Should -Be 'desc'
                $context.CustomSamplingContext | Should -Not -Be $null
                $context.CustomSamplingContext['user_id'] | Should -Be 42
                $context.CustomSamplingContext['search_results'] | Should -BeOfType [hashtable]
                $context.CustomSamplingContext['nullable'] | Should -Be $null
                $global:TraceSamplerExecuted = $true
            }
        }

        $transaction = Start-SentryTransaction 'foo' 'bar' 'desc' @{
            'user_id'        = 42
            'search_results' = @{}
            'nullable'       = $null
        }

        $global:TraceSamplerExecuted | Should -Be $true
    }

    It 'sets name, operation and description' {
        $global:TraceSamplerExecuted = $false
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.TracesSampler = [System.Func[Sentry.TransactionSamplingContext, System.Nullable`1[System.Double]]] {
                param([Sentry.TransactionSamplingContext]$context)

                $context.TransactionContext | Should -Not -Be $null
                $context.TransactionContext.Name | Should -Be 'foo'
                $context.TransactionContext.Operation | Should -Be 'bar'
                $context.TransactionContext.Description | Should -Be 'desc'
                $global:TraceSamplerExecuted = $true
            }
        }

        $transaction = Start-SentryTransaction 'foo' 'bar' 'desc'

        $global:TraceSamplerExecuted | Should -Be $true
    }

    It 'accepts TransactionContext' {
        $global:TraceSamplerExecuted = $false
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.TracesSampler = [System.Func[Sentry.TransactionSamplingContext, System.Nullable`1[System.Double]]] {
                param([Sentry.TransactionSamplingContext]$context)

                $context.TransactionContext | Should -Not -Be $null
                $context.TransactionContext.Name | Should -Be 'foo'
                $context.TransactionContext.Operation | Should -Be 'bar'
                $context.TransactionContext.Description | Should -Be 'desc'
                $global:TraceSamplerExecuted = $true
            }
        }

        $transaction = Start-SentryTransaction ([Sentry.TransactionContext]::new('foo', 'bar', $null, $null, $null, 'desc'))

        $global:TraceSamplerExecuted | Should -Be $true
    }

    It 'sets IsSampled correctly based on ForceSampled, with tracing disabled' -ForEach @($true, $false) {
        $ForceSampled = $_

        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
        }

        if ($ForceSampled)
        {
            $transaction = Start-SentryTransaction 'foo' 'bar' -ForceSampled
            $transaction.IsSampled | Should -Be $true
        }
        else
        {
            $transaction = Start-SentryTransaction 'foo' 'bar'
            $transaction.IsSampled | Should -Be $false
        }
    }

    It 'sets IsSampled correctly based on ForceSampled, with tracing enabled' -ForEach @($true, $false) {
        $ForceSampled = $_

        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.TracesSampleRate = 1.0
        }

        if ($ForceSampled)
        {
            $transaction = Start-SentryTransaction 'foo' 'bar' -ForceSampled
            $transaction.IsSampled | Should -Be $true
        }
        else
        {
            $transaction = Start-SentryTransaction 'foo' 'bar'
            $transaction.IsSampled | Should -Be $true
        }
    }
}

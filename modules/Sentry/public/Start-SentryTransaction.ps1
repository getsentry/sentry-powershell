function Start-SentryTransaction {
    [OutputType([Sentry.ITransactionTracer])]
    [CmdletBinding(DefaultParameterSetName = 'Basic')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Basic', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'BasicWithDescription', Position = 0)]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'Basic', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'BasicWithDescription', Position = 1)]
        [string] $Operation,

        [Parameter(ParameterSetName = 'BasicWithDescription', Position = 2)]
        [string] $Description = $null,

        [Parameter(Mandatory, ParameterSetName = 'TransactionContext', Position = 0)]
        [Sentry.ITransactionContext] $TransactionContext,

        [Parameter(ParameterSetName = 'Basic', Position = 2)]
        [Parameter(ParameterSetName = 'BasicWithDescription', Position = 3)]
        [Parameter(ParameterSetName = 'TransactionContext', Position = 1)]
        [hashtable] $CustomSamplingContext,

        [Parameter(ParameterSetName = 'Basic')]
        [Parameter(ParameterSetName = 'BasicWithDescription')]
        [Parameter(ParameterSetName = 'TransactionContext')]
        [switch] $ForceSampled
    )

    begin {
        if ($null -eq $TransactionContext) {
            $IsSampled = $null
            if ($ForceSampled) {
                $IsSampled = $true
            }
            $TransactionContext = [Sentry.TransactionContext]::new($Name, $Operation, $null, $null, $null, $Description, $null, $IsSampled)
        }

    }
    process {
        if ($CustomSamplingContext -eq $null) {
            return [Sentry.SentrySdk]::StartTransaction($TransactionContext)
        } else {
            $samplingContext = HashTableToDictionary $CustomSamplingContext
            return [Sentry.SentrySdk]::StartTransaction($TransactionContext, $samplingContext)
        }
    }
}

# Converts [hashtable] to [System.Collections.generic.dictionary]
function HashTableToDictionary([hashtable] $hash) {
    $dict = [System.Collections.Generic.Dictionary[string, object]]::new()
    foreach ($key in $hash.Keys) {
        $dict.Add($key, $hash[$key])
    }
    return $dict
}

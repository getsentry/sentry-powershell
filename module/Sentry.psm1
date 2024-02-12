function Sentry
{
    param(
        [Parameter(ValueFromPipeline = $true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(ValueFromPipeline = $true)]
        [System.Exception]
        $Exception,

        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Message
    )

    begin {}
    process
    {
        if ($ErrorRecord -ne $null)
        {
            # TODO details
            [Sentry.SentrySdk]::CaptureException($ErrorRecord.Exception)
        }
        if ($Exception -ne $null -and "$Exception" -ne "$Message")
        {
            [Sentry.SentrySdk]::CaptureException($Exception)
        }
        if ($Message -ne $null -and $Message -ne $ErrorRecord -and $Message -ne $Exception)
        {
            [Sentry.SentrySdk]::CaptureMessage($Message)
        }
    }
    end {}
}

function Invoke-WithSentry
{
    param(
        [scriptblock]
        $ScriptBlock
    )

    try
    {
        & $ScriptBlock
    }
    catch
    {
        $_ | Sentry
        throw
    }
}

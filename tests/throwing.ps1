# This file is used in stacktrace tests.
# Changes here may require changes in tests/stacktrace.test.ps1
# Especially in the contexts-lines checks.

function funcA($action, $param)
{
    funcB $action $param
}

function funcB
{
    [CmdletBinding()]
    param([string]$action, [string] $value)

    switch ($action)
    {
        'throw' { throw $value }
        'write' { Write-Error $value -ErrorAction Stop }
        'pass' { $value | Out-Sentry }
        'pipeline'
        {
            try
            {
                throw $value
            }
            catch
            {
                [System.Management.Automation.ErrorRecord]$ErrorRecord = $_
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
        }
    }
}

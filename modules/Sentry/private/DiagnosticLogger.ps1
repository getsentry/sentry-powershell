class DiagnosticLogger : Sentry.Extensibility.IDiagnosticLogger {
    hidden [Sentry.SentryLevel] $minimalLevel

    DiagnosticLogger([Sentry.SentryLevel] $minimalLevel) {
        $this.minimalLevel = $minimalLevel
    }

    [bool] IsEnabled([Sentry.SentryLevel] $level) {
        return $level -ge $this.minimalLevel
    }

    Log([Sentry.SentryLevel] $level, [string] $message, [Exception] $exception = $null, [object[]] $params) {
        # Important: Only format the string if there are args passed.
        # Otherwise, a pre-formatted string that contains braces can cause a FormatException.
        if ($params.Count -gt 0) {
            $message = $message -f $params
        }

        # Note, linefeed and newline chars are removed to guard against log injection attacks.
        $message = $message -replace '[\r\n]+', ' '

        $message = "[Sentry] $message"
        if ($null -ne $exception) {
            $message += [Environment]::NewLine
            $message += $exception | Out-String
        }

        switch ($level) {
            ([Sentry.SentryLevel]::Info) {
                Write-Verbose $message
            }
            ([Sentry.SentryLevel]::Warning) {
                Write-Warning $message
            }
            ([Sentry.SentryLevel]::Error) {
                Write-Error $message
            }
            ([Sentry.SentryLevel]::Fatal) {
                Write-Error $message
            }
            default {
                # Workaround for Windows Powershell issue of halting and asking for user confirmation.
                # see https://github.com/PowerShell/PowerShell/issues/5148
                if ($global:PSVersionTable.PSEdition -eq 'Desktop') {
                    $pref = Get-Variable DebugPreference
                    if (($null -ne $pref) -and ($pref.value -eq 'Inquire')) {
                        $DebugPreference = 'Continue'
                    }
                }

                Write-Debug $message
            }
        }
    }
}

# Regression tests for https://github.com/getsentry/sentry-powershell/issues/38
#
# Verifies that a script which captures an event and exits WITHOUT calling Stop-Sentry:
#   * exits cleanly (exit code 0) within a timeout (i.e. does not hang on exit), and
#   * still delivers the captured event.
#
# Historically the .NET SDK's automatic flush-on-exit hook (AppDomain.ProcessExit) was disabled
# in this module because it could hang/crash the process (sentry-dotnet#3141). That was fixed and
# the workaround was removed in #85, so omitting Stop-Sentry must now Just Work.

BeforeAll {
    $script:childScript = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)exit-flush-test-script.ps1"

    # Runs the exit-flush child script in a separate process and returns whether it exited cleanly
    # within the timeout, its exit code, and the delivered envelope content.
    function Invoke-ExitFlushChild {
        param(
            [Parameter(Mandatory)] [string] $Executable,
            [int] $TimeoutSeconds = 60
        )

        $outputFile = [IO.Path]::GetTempFileName()
        $stdout = [IO.Path]::GetTempFileName()
        $stderr = [IO.Path]::GetTempFileName()
        # FileTransport appends; start from an empty file.
        Remove-Item $outputFile -ErrorAction SilentlyContinue

        try {
            $proc = Start-Process -FilePath $Executable `
                -ArgumentList @('-NoProfile', '-File', $script:childScript, $outputFile) `
                -PassThru -NoNewWindow `
                -RedirectStandardOutput $stdout -RedirectStandardError $stderr

            $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
            if (-not $exited) {
                try { $proc.Kill() } catch {}
                return [PSCustomObject]@{
                    Exited   = $false
                    ExitCode = $null
                    Envelope = ''
                    StdOut   = (Get-Content -Raw $stdout -ErrorAction SilentlyContinue)
                    StdErr   = (Get-Content -Raw $stderr -ErrorAction SilentlyContinue)
                }
            }

            return [PSCustomObject]@{
                Exited   = $true
                ExitCode = $proc.ExitCode
                Envelope = (Get-Content -Raw $outputFile -ErrorAction SilentlyContinue)
                StdOut   = (Get-Content -Raw $stdout -ErrorAction SilentlyContinue)
                StdErr   = (Get-Content -Raw $stderr -ErrorAction SilentlyContinue)
            }
        } finally {
            Remove-Item $outputFile, $stdout, $stderr -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Automatic flush on exit (without Stop-Sentry)' {
    It 'Windows PowerShell' -Skip:($env:OS -ne 'Windows_NT') {
        $result = Invoke-ExitFlushChild -Executable 'powershell.exe'
        $result.Exited | Should -BeTrue -Because "the process must not hang on exit. StdErr: $($result.StdErr)"
        $result.ExitCode | Should -Be 0 -Because "the process must exit cleanly. StdErr: $($result.StdErr)"
        $result.Envelope | Should -Match 'hello-from-exit-flush-test' -Because 'the captured event must be delivered even without Stop-Sentry'
    }

    It 'PowerShell' {
        $result = Invoke-ExitFlushChild -Executable 'pwsh'
        $result.Exited | Should -BeTrue -Because "the process must not hang on exit. StdErr: $($result.StdErr)"
        $result.ExitCode | Should -Be 0 -Because "the process must exit cleanly. StdErr: $($result.StdErr)"
        $result.Envelope | Should -Match 'hello-from-exit-flush-test' -Because 'the captured event must be delivered even without Stop-Sentry'
    }
}

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
        # FileTransport appends; start from an empty file.
        Remove-Item $outputFile -ErrorAction SilentlyContinue

        # Use System.Diagnostics.Process directly rather than Start-Process: on Windows PowerShell 5.1
        # the object returned by `Start-Process -PassThru` does not reliably populate .ExitCode after
        # WaitForExit(timeout), whereas reading it from a Process we started ourselves works on both
        # editions.
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $Executable
        # ArgumentList isn't available on .NET Framework (WinPS 5.1), so build the argument string.
        $psi.Arguments = '-NoProfile -File "{0}" "{1}"' -f $script:childScript, $outputFile
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        # Read the streams asynchronously to avoid deadlocking if a pipe buffer fills.
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        try {
            $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
            if (-not $exited) {
                try { $proc.Kill() } catch {}
                return [PSCustomObject]@{
                    Exited   = $false
                    ExitCode = $null
                    Envelope = ''
                    StdOut   = $stdoutTask.Result
                    StdErr   = $stderrTask.Result
                }
            }

            return [PSCustomObject]@{
                Exited   = $true
                ExitCode = $proc.ExitCode
                Envelope = (Get-Content -Raw $outputFile -ErrorAction SilentlyContinue)
                StdOut   = $stdoutTask.Result
                StdErr   = $stderrTask.Result
            }
        } finally {
            $proc.Dispose()
            Remove-Item $outputFile -ErrorAction SilentlyContinue
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

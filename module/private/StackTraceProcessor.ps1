. "$privateDir/Get-SentryAssembliesDirectory.ps1"

# Note: we cannot implement ISentryEventProcessor in PowerShell directly because Windows Powershell breaks on the `Process` method.
# https://stackoverflow.com/questions/78001695/windows-powershell-implement-c-sharp-interface-with-reserved-words-as-method-n/78001981
# Instead, we have a thin c# implementation that takes a PowerShell callback to forward to.
# This way, we can keep the PowerShell code here, with all the access to System.Management.Automation we need.

Add-Type -TypeDefinition @'
public class StackTraceProcessorCs: Sentry.Extensibility.ISentryEventProcessor
{
    public System.Func<Sentry.SentryEvent, Sentry.SentryEvent> Callback;

    public Sentry.SentryEvent Process(Sentry.SentryEvent event_) {
        return Callback(event_);
    }
}
'@ -ReferencedAssemblies (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')

class StackTraceProcessor
{
    [Sentry.Protocol.SentryException]$SentryException
    [System.Management.Automation.InvocationInfo]$InvocationInfo
    [System.Management.Automation.CallStackFrame[]]$StackTraceFrames
    [string[]]$StackTraceString
    hidden [string[]] $modulePaths

    StackTraceProcessor()
    {
        if ($env:PSModulePath.Contains(';'))
        {
            # Windows
            $this.modulePaths = $env:PSModulePath -split ';'
        }
        else
        {
            # Unix
            $this.modulePaths = $env:PSModulePath -split ':'
        }
    }

    [Sentry.Extensibility.ISentryEventProcessor] GetSentryProcessor()
    {
        $cs = New-Object StackTraceProcessorCs
        $cs.Callback = $this.DoProcess
        return $cs
    }

    [Sentry.SentryEvent]DoProcess([Sentry.SentryEvent] $event_)
    {
        try
        {
            if ($null -ne $this.SentryException)
            {
                $this.ProcessException($event_)
            }
            elseif ($null -ne $event_.Message)
            {
                $this.ProcessMessage($event_)
            }
        }
        catch
        {
            $ErrorRecord = $_
            "$([StackTraceProcessor]) failed to update event $($event_.EventId):" | Write-Warning
            $ErrorRecord | Format-List * -Force | Out-String | Write-Warning
            $ErrorRecord.InvocationInfo | Format-List * | Out-String | Write-Warning
            $ErrorRecord.Exception | Format-List * -Force | Out-String | Write-Warning
        }

        return $event_
    }

    hidden ProcessMessage([Sentry.SentryEvent] $event_)
    {
        $this.PrependThread($event_, $this.GetStackTrace())
    }

    hidden ProcessException([Sentry.SentryEvent] $event_)
    {
        $this.SentryException.Stacktrace = $this.GetStackTrace()
        if ($this.SentryException.Stacktrace.Frames.Count -gt 0)
        {
            $topFrame = $this.SentryException.Stacktrace.Frames | Select-Object -Last 1
            $this.SentryException.Module = $topFrame.Module
        }

        # Add the c# exception to the front of the exception list, followed by whatever is already there.
        $newExceptions = New-Object System.Collections.Generic.List[Sentry.Protocol.SentryException]
        if ($null -ne $event_.SentryExceptions)
        {
            foreach ($e in $event_.SentryExceptions)
            {
                if ($null -eq $e.Mechanism)
                {
                    $e.Mechanism = [Sentry.Protocol.Mechanism]::new()
                }
                $e.Mechanism.Synthetic = $true
                $newExceptions.Add($e)
            }
        }
        $newExceptions.Add($this.SentryException)
        $event_.SentryExceptions = $newExceptions
        $this.PrependThread($event_, $this.SentryException.Stacktrace)
    }

    hidden PrependThread([Sentry.SentryEvent] $event_, [Sentry.SentryStackTrace] $sentryStackTrace)
    {
        $newThreads = New-Object System.Collections.Generic.List[Sentry.SentryThread]
        $thread = New-Object Sentry.SentryThread
        $thread.Id = 0
        $thread.Name = 'PowerShell Script'
        $thread.Crashed = $true
        $thread.Current = $true
        $thread.Stacktrace = $sentryStackTrace
        $newThreads.Add($thread)
        if ($null -ne $event_.SentryThreads)
        {
            foreach ($t in $event_.SentryThreads)
            {
                $t.Crashed = $false
                $t.Current = $false
                $newThreads.Add($t)
            }
        }
        $event_.SentryThreads = $newThreads
    }

    hidden [Sentry.SentryStackTrace]GetStackTrace()
    {
        # We collect all frames and then reverse them to the order expected by Sentry (caller->callee).
        # Do not try to make this code go backwards, because it relies on the InvocationInfo from the previous frame.
        $sentryFrames = New-Object System.Collections.Generic.List[Sentry.SentryStackFrame]
        if ($null -ne $this.StackTraceFrames)
        {
            $sentryFrames.Capacity = $this.StackTraceFrames.Count + 1
        }
        else
        {
            $sentryFrames.Capacity = $this.StackTraceString.Count + 1
        }

        if ($null -ne $this.StackTraceFrames)
        {
            # Note: if InvocationInfo is present, use it to fill the first frame. This is the case for ErrroRecord handling
            # and has the information about the actual script file and line that have thrown the exception.
            if ($null -ne $this.InvocationInfo)
            {
                $sentryFrames.Add($this.CreateFrame($this.InvocationInfo))
            }

            foreach ($frame in $this.StackTraceFrames)
            {
                $sentryFrames.Add($this.CreateFrame($frame))
            }
        }
        else
        {
            foreach ($frame in $this.StackTraceString)
            {
                $sentryFrame = $this.CreateFrame($frame)
                # Note: if InvocationInfo is present, use it to update the first frame. This is the case for ErrroRecord handling
                # and has the information about the actual script file and line that have thrown the exception.
                if ($sentryFrames.Count -eq 0 -and $null -ne $this.InvocationInfo)
                {
                    $sentryFrameInitial = $this.CreateFrame($this.InvocationInfo)
                    if ($sentryFrameInitial.AbsolutePath -eq $sentryFrame.AbsolutePath -and $sentryFrameInitial.LineNumber -eq $sentryFrame.LineNumber)
                    {
                        $sentryFrame.ContextLine = $sentryFrameInitial.ContextLine
                        $sentryFrame.ColumnNumber = $sentryFrameInitial.ColumnNumber
                    }
                    else
                    {
                        $sentryFrames.Add($sentryFrameInitial)
                    }
                }
                $sentryFrames.Add($sentryFrame)
            }
        }

        foreach ($sentryFrame in $sentryFrames)
        {
            # Update module info
            $this.SetModule($sentryFrame)
            $sentryFrame.InApp = $null -eq $sentryFrame.Module
            $this.SetContextLines($sentryFrame)
        }

        $sentryFrames.Reverse()
        $stacktrace_ = [Sentry.SentryStackTrace]::new()
        $stacktrace_.Frames = $sentryFrames
        return $stacktrace_
    }

    hidden [Sentry.SentryStackFrame] CreateFrame([System.Management.Automation.InvocationInfo] $info)
    {
        $sentryFrame = [Sentry.SentryStackFrame]::new()
        $sentryFrame.AbsolutePath = $info.ScriptName
        $sentryFrame.LineNumber = $info.ScriptLineNumber
        $sentryFrame.ColumnNumber = $info.OffsetInLine
        $sentryFrame.ContextLine = $info.Line.TrimEnd()
        return $sentryFrame
    }

    hidden [Sentry.SentryStackFrame] CreateFrame([System.Management.Automation.CallStackFrame] $frame)
    {
        $sentryFrame = [Sentry.SentryStackFrame]::new()
        $this.SetScriptInfo($sentryFrame, $frame)
        $this.SetModule($sentryFrame)
        $this.SetFunction($sentryFrame, $frame)
        return $sentryFrame
    }

    hidden [Sentry.SentryStackFrame] CreateFrame([string] $frame)
    {
        $sentryFrame = [Sentry.SentryStackFrame]::new()
        # at funcB, C:\dev\sentry-powershell\tests\capture.tests.ps1: line 363
        $regex = 'at (?<Function>[^,]+), (?<AbsolutePath>.+): line (?<LineNumber>\d+)'
        if ($frame -match $regex)
        {
            $sentryFrame.AbsolutePath = $Matches.AbsolutePath
            $sentryFrame.LineNumber = [int]$Matches.LineNumber
            $sentryFrame.Function = $Matches.Function
        }
        else
        {
            Write-Warning "Failed to parse stack frame: $frame"
        }
        return $sentryFrame
    }

    hidden SetScriptInfo([Sentry.SentryStackFrame] $sentryFrame, [System.Management.Automation.CallStackFrame] $frame)
    {
        if ($null -ne $frame.ScriptName)
        {
            $sentryFrame.AbsolutePath = $frame.ScriptName
            $sentryFrame.LineNumber = $frame.ScriptLineNumber
        }
        elseif ($null -ne $frame.Position -and $null -ne $frame.Position.File)
        {
            $sentryFrame.AbsolutePath = $frame.Position.File
            $sentryFrame.LineNumber = $frame.Position.StartLineNumber
            $sentryFrame.ColumnNumber = $frame.Position.StartColumnNumber
        }
    }

    hidden SetModule([Sentry.SentryStackFrame] $sentryFrame)
    {
        if ($null -ne $sentryFrame.AbsolutePath)
        {
            if ($prefix = $this.modulePaths | Where-Object { $sentryFrame.AbsolutePath.StartsWith($_) })
            {
                $relativePath = $sentryFrame.AbsolutePath.Substring($prefix.Length + 1)
                $sentryFrame.Module = ($relativePath -split '[\\/]') | Select-Object -First 1
            }
        }
    }

    hidden SetFunction([Sentry.SentryStackFrame] $sentryFrame, [System.Management.Automation.CallStackFrame] $frame)
    {
        if ($null -eq $sentryFrame.AbsolutePath -and $frame.FunctionName -eq '<ScriptBlock>' -and $null -ne $frame.Position)
        {
            $sentryFrame.Function = $frame.Position.Text
        }
        else
        {
            $sentryFrame.Function = $frame.FunctionName
        }
    }

    hidden SetContextLines([Sentry.SentryStackFrame] $sentryFrame)
    {
        if ($null -ne $sentryFrame.AbsolutePath -and $sentryFrame.LineNumber -ge 1 -and (Test-Path $sentryFrame.AbsolutePath -PathType Leaf))
        {
            try
            {
                $lines = Get-Content $sentryFrame.AbsolutePath -TotalCount ($sentryFrame.LineNumber + 5)
                if ($null -eq $sentryFrame.ContextLine)
                {
                    $sentryFrame.ContextLine = $lines[$sentryFrame.LineNumber - 1]
                }
                if ($sentryFrame.LineNumber -gt 6)
                {
                    $lines = $lines | Select-Object -Skip ($sentryFrame.LineNumber - 6)
                }
                # TODO currently these are read-only in sentry-dotnet. We should change that.
                # $sentryFrame.PreContext = $lines | Select-Object -First 5
                # $sentryFrame.PostContext = $lines | Select-Object -Last 5
            }
            catch
            {
                Write-Warning "Failed to read context lines for $($sentryFrame.AbsolutePath): $_"
            }
        }
    }
}

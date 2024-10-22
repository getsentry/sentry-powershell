class StackTraceProcessor : SentryEventProcessor
{
    [Sentry.Protocol.SentryException]$SentryException
    [System.Management.Automation.InvocationInfo]$InvocationInfo
    [System.Management.Automation.CallStackFrame[]]$StackTraceFrames
    [string[]]$StackTraceString
    hidden [string[]] $modulePaths
    hidden [hashtable] $pwshModules = @{}

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

    [Sentry.SentryEvent]DoProcess([Sentry.SentryEvent] $event_)
    {
        if ($null -ne $this.SentryException)
        {
            $this.ProcessException($event_)
        }
        elseif ($null -ne $event_.Message)
        {
            $this.ProcessMessage($event_)
        }

        # Add modules present in PowerShell
        foreach ($module in $this.pwshModules.GetEnumerator())
        {
            $event_.Modules[$module.Name] = $module.Value
        }

        # Add .NET modules. Note: we don't let sentry-dotnet do it because it would just add all the loaded assemblies,
        # regardless of their presence in a stacktrace. So we set the option ReportAssembliesMode=None in [Start-Sentry].
        foreach ($thread in $event_.SentryThreads)
        {
            foreach ($frame in $thread.Stacktrace.Frames)
            {
                # .NET SDK sets the assembly info to frame.Package, for example:
                # "System.Private.CoreLib, Version=8.0.0.0, Culture=neutral, PublicKeyToken=7cec85d7bea7798e"
                if ($frame.Package -match '^(?<Assembly>[^,]+), Version=(?<Version>[^,]+), ')
                {
                    $event_.Modules[$Matches.Assembly] = $Matches.Version
                }
            }
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
        if ($null -ne $this.StackTraceString)
        {
            $sentryFrames.Capacity = $this.StackTraceString.Count + 1
            # Note: if InvocationInfo is present, use it to update:
            #  - the first frame (in case of `$_ | Out-Sentry` in a catch clause).
            #  - the second frame (in case of `write-error` and `$_ | Out-Sentry` in a trap).
            if ($null -ne $this.InvocationInfo)
            {
                $sentryFrameInitial = $this.CreateFrame($this.InvocationInfo)
            }
            else
            {
                $sentryFrameInitial = $null
            }

            foreach ($frame in $this.StackTraceString)
            {
                $sentryFrame = $this.CreateFrame($frame)
                if ($null -ne $sentryFrameInitial -and $sentryFrames.Count -lt 2)
                {
                    if ($sentryFrameInitial.AbsolutePath -eq $sentryFrame.AbsolutePath -and $sentryFrameInitial.LineNumber -eq $sentryFrame.LineNumber)
                    {
                        $sentryFrame.ContextLine = $sentryFrameInitial.ContextLine
                        $sentryFrame.ColumnNumber = $sentryFrameInitial.ColumnNumber
                        $sentryFrameInitial = $null
                    }
                }
                $sentryFrames.Add($sentryFrame)
            }
            if ($null -ne $sentryFrameInitial)
            {
                $sentryFrames.Insert(0, $sentryFrameInitial)
            }
        }
        elseif ($null -ne $this.StackTraceFrames)
        {
            $sentryFrames.Capacity = $this.StackTraceFrames.Count + 1
            foreach ($frame in $this.StackTraceFrames)
            {
                $sentryFrames.Add($this.CreateFrame($frame))
            }
        }

        foreach ($sentryFrame in $sentryFrames)
        {
            # Update module info
            $this.SetModule($sentryFrame)
            $sentryFrame.InApp = [string]::IsNullOrEmpty($sentryFrame.Module)
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
        $regex = 'at (?<Function>[^,]*), (?<AbsolutePath>.*): line (?<LineNumber>\d*)'
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
        if (![string]::IsNullOrEmpty($frame.ScriptName))
        {
            $sentryFrame.AbsolutePath = $frame.ScriptName
            $sentryFrame.LineNumber = $frame.ScriptLineNumber
        }
        elseif (![string]::IsNullOrEmpty($frame.Position) -and ![string]::IsNullOrEmpty($frame.Position.File))
        {
            $sentryFrame.AbsolutePath = $frame.Position.File
            $sentryFrame.LineNumber = $frame.Position.StartLineNumber
            $sentryFrame.ColumnNumber = $frame.Position.StartColumnNumber
        }
    }

    hidden SetModule([Sentry.SentryStackFrame] $sentryFrame)
    {
        if (![string]::IsNullOrEmpty($sentryFrame.AbsolutePath))
        {
            if ($prefix = $this.modulePaths | Where-Object { $sentryFrame.AbsolutePath.StartsWith($_) })
            {
                $relativePath = $sentryFrame.AbsolutePath.Substring($prefix.Length + 1)
                $parts = $relativePath -split '[\\/]'
                $sentryFrame.Module = $parts | Select-Object -First 1
                if ($parts.Length -ge 2)
                {
                    if (-not $this.pwshModules.ContainsKey($parts[0]))
                    {
                        $this.pwshModules[$parts[0]] = $parts[1]
                    }
                    elseif ($this.pwshModules[$parts[0]] -ne $parts[1])
                    {
                        $this.pwshModules[$parts[0]] = $this.pwshModules[$parts[0]] + ", $($parts[1])"
                    }
                }
            }
        }
    }

    hidden SetFunction([Sentry.SentryStackFrame] $sentryFrame, [System.Management.Automation.CallStackFrame] $frame)
    {
        if ([string]::IsNullOrEmpty($sentryFrame.AbsolutePath) -and $frame.FunctionName -eq '<ScriptBlock>' -and ![string]::IsNullOrEmpty($frame.Position))
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
        if ([string]::IsNullOrEmpty($sentryFrame.AbsolutePath) -or $sentryFrame.LineNumber -lt 1)
        {
            return
        }

        if ((Test-Path $sentryFrame.AbsolutePath -IsValid) -and (Test-Path $sentryFrame.AbsolutePath -PathType Leaf))
        {
            try
            {
                $lines = Get-Content $sentryFrame.AbsolutePath -TotalCount ($sentryFrame.LineNumber + 5)
                if ($null -eq $sentryFrame.ContextLine)
                {
                    $sentryFrame.ContextLine = $lines[$sentryFrame.LineNumber - 1]
                }
                $preContextCount = [math]::Min(5, $sentryFrame.LineNumber - 1)
                $postContextCount = [math]::Min(5, $lines.Count - $sentryFrame.LineNumber)
                if ($sentryFrame.LineNumber -gt 6)
                {
                    $lines = $lines | Select-Object -Skip ($sentryFrame.LineNumber - 6)
                }
                # Note: these are read-only in sentry-dotnet so we just update the underlying lists instead of replacing.
                $sentryFrame.PreContext.Clear()
                $lines | Select-Object -First $preContextCount | ForEach-Object { $sentryFrame.PreContext.Add($_) }
                $sentryFrame.PostContext.Clear()
                $lines | Select-Object -Last $postContextCount  | ForEach-Object { $sentryFrame.PostContext.Add($_) }
            }
            catch
            {
                Write-Warning "Failed to read context lines for $($sentryFrame.AbsolutePath): $_"
            }
        }
    }
}

BeforeAll {
    . "$PSScriptRoot/../modules/Sentry/private/StackTraceProcessor.ps1"
}

Describe 'StackTraceProcessor' {
    It 'Parses stack trace properly' {
        $event_ = [Sentry.SentryEvent]::new()
        $event_.Message = 'Test'
        $event_.Level = [Sentry.SentryLevel]::Info

        $sut = [StackTraceProcessor]::new()
        $sut.StackTraceString = 'at funcB, C:\dev\sentry-powershell\tests\throwing.ps1: line 17
at <ScriptBlock>, <No file>: line 1
at <ScriptBlock>, : line 3' -split "[`r`n]+"
        $sut.process($event_)

        $frames = $event_.SentryThreads[0].Stacktrace.Frames
        $frames[0].Function | Should -Be '<ScriptBlock>'
        $frames[0].AbsolutePath | Should -Be ''
        $frames[0].LineNumber | Should -Be 3
        $frames[1].Function | Should -Be '<ScriptBlock>'
        $frames[1].AbsolutePath | Should -Be '<No file>'
        $frames[1].LineNumber | Should -Be 1
        $frames[2].Function | Should -Be 'funcB'
        $frames[2].AbsolutePath | Should -Be 'C:\dev\sentry-powershell\tests\throwing.ps1'
        $frames[2].LineNumber | Should -Be 17
    }
}

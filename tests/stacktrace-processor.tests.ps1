BeforeAll {
    . "$PSScriptRoot/../modules/Sentry/private/StackTraceProcessor.ps1"
    $global:SentryPowershellRethrowErrors = $true
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
}

Describe 'StackTraceProcessor' {
    It 'Parses stack trace properly' {
        $event_ = [Sentry.SentryEvent]::new()
        $event_.Message = 'Test'
        $event_.Level = [Sentry.SentryLevel]::Info

        $sut = [StackTraceProcessor]::new([Sentry.SentryOptions]::new())
        $sut.StackTraceString = 'at funcB, C:\dev\sentry-powershell\tests\throwing.ps1: line 17
at <ScriptBlock>, <No file>: line 1
at <ScriptBlock>, : line 3' -split "[`r`n]+"
        $sut.process($event_)

        $frames = $event_.SentryThreads[0].Stacktrace.Frames
        $frames[0].Function | Should -Be '<ScriptBlock>'
        $frames[0].AbsolutePath | Should -Be ''
        $frames[0].LineNumber | Should -Be 3
        $frames[1].Function | Should -Be '<ScriptBlock>'
        $frames[1].AbsolutePath | Should -Be $null
        $frames[1].LineNumber | Should -Be 1
        $frames[2].Function | Should -Be 'funcB'
        $frames[2].AbsolutePath | Should -Be 'C:\dev\sentry-powershell\tests\throwing.ps1'
        $frames[2].LineNumber | Should -Be 17
    }

    Context 'ResolveInApp' {
        BeforeAll {
            function MakeFrame([string] $module) {
                $f = [Sentry.SentryStackFrame]::new()
                $f.Module = $module
                $f
            }
        }

        It 'Defaults user-script frames (no module) to in-app' {
            $sut = [StackTraceProcessor]::new([Sentry.SentryOptions]::new())
            $sut.ResolveInApp((MakeFrame $null)) | Should -BeTrue
            $sut.ResolveInApp((MakeFrame '')) | Should -BeTrue
        }

        It 'Defaults module frames to not-in-app' {
            $sut = [StackTraceProcessor]::new([Sentry.SentryOptions]::new())
            $sut.ResolveInApp((MakeFrame 'Pester')) | Should -BeFalse
        }

        It 'Honors InAppInclude for module frames' {
            $options = [Sentry.SentryOptions]::new()
            $options.AddInAppInclude('MyApp')
            $sut = [StackTraceProcessor]::new($options)
            $sut.ResolveInApp((MakeFrame 'MyApp')) | Should -BeTrue
            $sut.ResolveInApp((MakeFrame 'Pester')) | Should -BeFalse
        }

        It 'Honors InAppExclude for module frames' {
            # Module frames already default to not-in-app, so an exclude can only be *observed* when it
            # overrides an include. Include both modules, exclude one, and verify only the other stays in-app.
            $options = [Sentry.SentryOptions]::new()
            $options.AddInAppInclude('Included')
            $options.AddInAppInclude('Excluded')
            $options.AddInAppExclude('Excluded')
            $sut = [StackTraceProcessor]::new($options)
            $sut.ResolveInApp((MakeFrame 'Excluded')) | Should -BeFalse
            $sut.ResolveInApp((MakeFrame 'Included')) | Should -BeTrue
        }

        It 'Matches prefix on dotted module names' {
            $options = [Sentry.SentryOptions]::new()
            $options.AddInAppInclude('MyApp')
            $sut = [StackTraceProcessor]::new($options)
            $sut.ResolveInApp((MakeFrame 'MyApp.Submodule')) | Should -BeTrue
            $sut.ResolveInApp((MakeFrame 'MyAppOther')) | Should -BeFalse
        }

        It 'Matches case-insensitively for both exact and dotted-prefix' {
            $options = [Sentry.SentryOptions]::new()
            $options.AddInAppInclude('myapp')
            $sut = [StackTraceProcessor]::new($options)
            $sut.ResolveInApp((MakeFrame 'MyApp')) | Should -BeTrue
            $sut.ResolveInApp((MakeFrame 'MyApp.Submodule')) | Should -BeTrue
        }

        It 'Honors regex include patterns' {
            $options = [Sentry.SentryOptions]::new()
            $options.AddInAppIncludeRegex('^My.*App$')
            $sut = [StackTraceProcessor]::new($options)
            $sut.ResolveInApp((MakeFrame 'MyAwesomeApp')) | Should -BeTrue
            $sut.ResolveInApp((MakeFrame 'OtherApp')) | Should -BeFalse
        }

        It 'InAppExclude wins over InAppInclude' {
            $options = [Sentry.SentryOptions]::new()
            $options.AddInAppInclude('Foo')
            $options.AddInAppExclude('Foo')
            $sut = [StackTraceProcessor]::new($options)
            $sut.ResolveInApp((MakeFrame 'Foo')) | Should -BeFalse
        }

        It 'MatchesAny operates on plain records without reflection' {
            # The hot path consumes normalized { String; Regex } records (produced once in the ctor),
            # so it must not depend on Sentry.StringOrRegex internals.
            $stringPattern = [PSCustomObject]@{ String = 'MyApp'; Regex = $null }
            $regexPattern = [PSCustomObject]@{ String = $null; Regex = [regex]'^Other.*' }
            [StackTraceProcessor]::MatchesAny(@($stringPattern), 'MyApp.Sub') | Should -BeTrue
            [StackTraceProcessor]::MatchesAny(@($stringPattern), 'Unrelated') | Should -BeFalse
            [StackTraceProcessor]::MatchesAny(@($regexPattern), 'OtherThing') | Should -BeTrue
            [StackTraceProcessor]::MatchesAny(@(), 'MyApp') | Should -BeFalse
            [StackTraceProcessor]::MatchesAny($null, 'MyApp') | Should -BeFalse
        }
    }
}

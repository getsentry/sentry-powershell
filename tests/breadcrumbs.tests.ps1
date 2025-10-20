BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $global:SentryPowershellRethrowErrors = $true
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
}

Describe 'Add-SentryBreadcrumb' {
    BeforeEach {
        $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
        $transport = [RecordingTransport]::new()
        StartSentryForEventTests ([ref] $events) ([ref] $transport)
    }

    AfterEach {
        $events.Clear()
        Stop-Sentry
    }

    It 'Pipes a message' {
        'hello there' | Add-SentryBreadcrumb
        'msg' | Out-Sentry

        $events[0].Breadcrumbs.Count | Should -Be 1
        $events[0].Breadcrumbs[0].Message | Should -Be 'hello there'
        $events[0].Breadcrumbs[0].Data | Should -Be $null
    }

    It 'Adds data' {
        'hello there' | Add-SentryBreadcrumb -Data @{ 'key' = 'value' }
        'msg' | Out-Sentry

        $events[0].Breadcrumbs.Count | Should -Be 1
        $events[0].Breadcrumbs[0].Message | Should -Be 'hello there'
        $events[0].Breadcrumbs[0].Data['key'] | Should -Be 'value'
    }

    It 'Passes all args' {
        Add-SentryBreadcrumb -Message 'hello there' -Category 'cat' -Type 'foo' -Level Warning -Data @{ 'key' = 'value' }
        'msg' | Out-Sentry

        $events[0].Breadcrumbs.Count | Should -Be 1
        $events[0].Breadcrumbs[0].Message | Should -Be 'hello there'
        $events[0].Breadcrumbs[0].Level | Should -Be ([Sentry.BreadcrumbLevel]::Warning)
        $events[0].Breadcrumbs[0].Category | Should -Be 'cat'
        $events[0].Breadcrumbs[0].Type | Should -Be 'foo'
        $events[0].Breadcrumbs[0].Data['key'] | Should -Be 'value'
    }
}

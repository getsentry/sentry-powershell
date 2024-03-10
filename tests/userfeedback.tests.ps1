BeforeAll {
    . "$PSScriptRoot/utils.ps1"
}

Describe 'UserFeedback' {
    BeforeEach {
        $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
        $transport = [RecordingTransport]::new()
        StartSentryForEventTests ([ref] $events) ([ref] $transport)
    }

    AfterEach {
        $events.Clear()
        $transport.Envelopes.Clear()
        Stop-Sentry
    }

    It 'Out-Sentry returns an event ID for messages' {
        $eventId = 'msg' | Out-Sentry
        $eventId | Should -BeOfType [Sentry.SentryId]
        $eventId.ToString().Length | Should -Be 32
    }

    It 'Out-Sentry returns an event ID for an error record' {
        try
        {
            throw 'error'
        }
        catch
        {
            $eventId = $_ | Out-Sentry
        }
        $eventId | Should -BeOfType [Sentry.SentryId]
        $eventId.ToString().Length | Should -Be 32
    }

    It 'Feedback gets captured' {
        $eventId = 'msg' | Out-Sentry

        $eventId | Should -BeOfType [Sentry.SentryId]
        [Sentry.SentrySdk]::Flush()
        $transport.Envelopes.Count | Should -Be 1

        [Sentry.SentrySdk]::CaptureUserFeedback($eventId, 'email@example.com', 'comments', 'name')
        [Sentry.SentrySdk]::Flush()
        $transport.Envelopes.Count | Should -Be 2
        $envelopeItem = $transport.Envelopes.ToArray()[1].Items[0]
        $envelopeItem.Header['type'] | Should -Be 'user_report'
        $envelopeItem.Payload.Source.EventId | Should -Be $eventId
        $envelopeItem.Payload.Source.Name | Should -Be 'name'
        $envelopeItem.Payload.Source.Email | Should -Be 'email@example.com'
        $envelopeItem.Payload.Source.Comments | Should -Be 'comments'
    }

}

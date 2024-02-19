class EventUpdater : SentryEventProcessor
{
    [Sentry.SentryEvent]DoProcess([Sentry.SentryEvent] $event_)
    {
        $event_.Platform = 'powershell'
        return $event_
    }
}

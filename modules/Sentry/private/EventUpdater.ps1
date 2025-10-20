class EventUpdater : SentryEventProcessor {
    [Sentry.SentryEvent]DoProcess([Sentry.SentryEvent] $event_) {
        $event_.Platform = 'powershell'

        # Clear useless release set by the .NET SDK (referring to the PowerShell assembly version)
        # "pwsh@7.4.1 SHA: 6a98b28414948626f1b29a5e8b062e73b7ff165a+6a98b28414948626f1b29a5e8b062e73b7ff165a"
        if ($event_.Release -match "pwsh@$($global:PSVersionTable.PSVersion) .*") {
            $event_.Release = $null
        }

        return $event_
    }
}

class SentryEventProcessor : SentryEventProcessor_ {
    [Sentry.SentryEvent]DoProcess([Sentry.SentryEvent] $event_) {
        throw [NotImplementedException]::new('You must override SentryEventProcessor::DoProcess()')
    }

    [Sentry.SentryEvent]Process_([Sentry.SentryEvent] $event_) {
        try {
            return $this.DoProcess($event_)
        } catch {
            $ErrorRecord = $_
            "$($this.GetType()) failed to process event $($event_.EventId):" | Write-Warning
            $ErrorRecord | Format-List * -Force | Out-String | Write-Warning
            $ErrorRecord.InvocationInfo | Format-List * | Out-String | Write-Warning
            $ErrorRecord.Exception | Format-List * -Force | Out-String | Write-Warning
            return $event_
        }
    }
}

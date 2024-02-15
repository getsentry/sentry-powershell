// This is an abstract class for any PowerShell event processors. It gets around an issue with Windows PowerShell
// failing to compile scripts that have a method name `Process`, which is a reserved word.
public abstract class SentryEventProcessor : Sentry.Extensibility.ISentryEventProcessor
{
    public Sentry.SentryEvent Process(Sentry.SentryEvent event_)
    {
        return DoProcess(event_);
    }

    protected abstract Sentry.SentryEvent DoProcess(Sentry.SentryEvent event_);
}
```
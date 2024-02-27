// This is an abstract class for any PowerShell event processors. It gets around an issue with Windows PowerShell
// failing to compile scripts that have a method name `Process`, which is a reserved word.
// https://stackoverflow.com/questions/78001695/windows-powershell-implement-c-sharp-interface-with-reserved-words-as-method-n/78001981
// This way, we can keep the PowerShell implementation of the event processor, with access to System.Management.Automation, etc.
public abstract class SentryEventProcessor_ : Sentry.Extensibility.ISentryEventProcessor
{
    public Sentry.SentryEvent Process(Sentry.SentryEvent event_)
    {
        return Process_(event_);
    }

    protected abstract Sentry.SentryEvent Process_(Sentry.SentryEvent event_);
}

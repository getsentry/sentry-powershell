# Wrapper to expose Sentry.Internal.SdkComposer::CreateHttpTransport()
function New-HttpTransport {
    [OutputType([Sentry.Extensibility.ITransport])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Sentry.SentryOptions] $options
    )

    $assembly = [Sentry.SentrySdk].Assembly
    $type = $assembly.GetType('Sentry.Internal.SdkComposer')
    $composer = [Activator]::CreateInstance($type, @($options))

    $method = $type.GetMethod('CreateHttpTransport', [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public)
    return $method.Invoke($composer, @())
}

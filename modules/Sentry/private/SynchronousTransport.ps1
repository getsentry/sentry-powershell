# Take Sentry's SerializableHttpContent, convert it to a string, and send via PowerShell's Invoke-WebRequest,
# then translate the response back to a .NET HttpResponseMessage.
# There are limited options to perform synchronous operations in Windows PowerShell 5.1 on .NET 4.6, so this is a workaround.
class SynchronousTransport : Sentry.Http.HttpTransportBase, Sentry.Extensibility.ITransport {
    [Sentry.Extensibility.IDiagnosticLogger] $logger
    # PowerShell 7.5.2+ changed how property assignment works in constructors when inheriting from .NET classes.
    # Using a hashtable instead of individual [System.Reflection.MethodInfo] properties works around this issue.
    # See: https://github.com/PowerShell/PowerShell/releases/tag/v7.5.2
    [hashtable] $reflectionMethods = @{}

    SynchronousTransport([Sentry.SentryOptions] $options) : base($options) {
        $this.logger = $options.DiagnosticLogger
        if ($null -eq $this.logger) {
            $this.logger = Get-Variable -Scope script -Name SentryPowerShellDiagnosticLogger -ValueOnly -ErrorAction SilentlyContinue
        }

        # These are internal methods, so we need to use reflection to access them.
        $instanceMethod = [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public;
        $this.reflectionMethods['ProcessEnvelope'] = [Sentry.Http.HttpTransportBase].GetMethod('ProcessEnvelope', $instanceMethod)
        if ($null -eq $this.reflectionMethods['ProcessEnvelope']) {
            throw "Failed to find ProcessEnvelope method on Sentry.Http.HttpTransportBase"
        }

        $this.reflectionMethods['CreateRequest'] = [Sentry.Http.HttpTransportBase].GetMethod('CreateRequest', $instanceMethod)
        if ($null -eq $this.reflectionMethods['CreateRequest']) {
            throw "Failed to find CreateRequest method on Sentry.Http.HttpTransportBase"
        }

        $EnvelopeHttpContentType = [Sentry.SentrySdk].Assembly.GetType('Sentry.Internal.Http.EnvelopeHttpContent')
        if ($null -eq $EnvelopeHttpContentType) {
            throw "Failed to find Sentry.Internal.Http.EnvelopeHttpContent type"
        }

        $this.reflectionMethods['SerializeToStream'] = $EnvelopeHttpContentType.GetMethod('SerializeToStream', $instanceMethod)
        if ($null -eq $this.reflectionMethods['SerializeToStream']) {
            throw "Failed to find SerializeToStream method on EnvelopeHttpContent"
        }
    }

    [System.Threading.Tasks.Task] SendEnvelopeAsync([Sentry.Protocol.Envelopes.Envelope] $envelope, [System.Threading.CancellationToken]$cancellationToken = [System.Threading.CancellationToken]::None) {
        $processedEnvelope = $this.reflectionMethods['ProcessEnvelope'].Invoke($this, @($envelope))
        if ($processedEnvelope.Items.count -gt 0) {
            $request = $this.reflectionMethods['CreateRequest'].Invoke($this, @($processedEnvelope))

            $headers = @{}
            foreach ($header in $request.Headers) {
                $Key = $header.Key
                $Value = $header.Value.Trim() -join ', '
                $headers[$Key] = $Value
            }

            $memoryStream = [System.IO.MemoryStream]::new()
            $this.reflectionMethods['SerializeToStream'].Invoke($request.Content, @($memoryStream, $null, $cancellationToken))
            $memoryStream.Position = 0

            if ($null -ne $this.logger) {
                $this.logger.Log([Sentry.SentryLevel]::Debug, 'Sending content synchronously, Content-Length: {0}', $null, $memoryStream.Length)
            }

            $ProgressPreference = 'SilentlyContinue'
            $psResponse = Invoke-WebRequest -Uri $request.RequestUri -Method $request.Method.Method -Headers $headers -Body $memoryStream -UseBasicParsing

            $response = [System.Net.Http.HttpResponseMessage]::new($psResponse.StatusCode)
            $contentType = $psResponse.Headers['Content-Type']
            if ($null -eq $contentType) {
                $contentType = 'application/json'
            }
            $response.Content = [System.Net.Http.StringContent]::new($psResponse.Content, [System.Text.Encoding]::UTF8, $contentType)

            foreach ($header in $psResponse.Headers.GetEnumerator()) {
                $response.Headers.TryAddWithoutValidation($header.Key, $header.Value)
            }

            $this.HandleResponse($response, $processedEnvelope)
        }

        return [System.Threading.Tasks.Task]::CompletedTask
    }
}

Add-Type -AssemblyName System.Net.Http

class SynchronousTransport : Sentry.Http.HttpTransportBase, Sentry.Extensibility.ITransport
{
    hidden [System.Net.Http.HttpClient] $httpClient
    hidden [Sentry.SentryOptions] $options

    SynchronousTransport([Sentry.SentryOptions] $options)
        : base($options)
    {
        $this.options = $options
        $this.httpClient = [System.Net.Http.HttpClient]::new()
    }

    [System.Threading.Tasks.Task] SendEnvelopeAsync([Sentry.Protocol.Envelopes.Envelope] $envelope, [System.Threading.CancellationToken]$cancellationToken = [System.Threading.CancellationToken]::None)
    {
        # Take Sentry's SerializableHttpContent, convert it to a string, and send via PowerShell's Invoke-WebRequest, then translate the response back to a .NET HttpResponseMessage.
        # There are limited options to perform synchronous operations in Windows PowerShell 5.1 on .NET 4.6, so this is a workaround.
        $assembly = [Sentry.SentrySdk].Assembly
        $type = $assembly.GetType('Sentry.Http.HttpTransportBase')
        $ProcessEnvelope = $type.GetMethod('ProcessEnvelope', [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public)
        $CreateRequest = $type.GetMethod('CreateRequest', [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public)
        $HandleResponse = $type.GetMethod('HandleResponse', [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public)

        $processedEnvelope = $ProcessEnvelope.Invoke($this, @($envelope))
        if ($processedEnvelope.Items.count -gt 0)
        {
            $request = $CreateRequest.Invoke($this, @($processedEnvelope))

            $headers = @{}
            foreach ($header in $request.Headers) {
                $Key = $header.Key
                $Value = $header.Value.Trim() -join ", "
                $headers[$Key] = $Value
            }

            $EnvelopeHttpContentType = $assembly.GetType('Sentry.Internal.Http.EnvelopeHttpContent')
            $SerializeToStream = $EnvelopeHttpContentType.GetMethod('SerializeToStream', [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public)

            $memoryStream = [System.IO.MemoryStream]::new()
            $SerializeToStream.Invoke($request.Content, @($memoryStream, $null, $cancellationToken))
            $memoryStream.Position = 0

            $reader = New-Object System.IO.StreamReader($memoryStream)
            $content = $reader.ReadToEnd()
            $reader.Close()

            $this.options.DiagnosticLogger.Log([Sentry.SentryLevel]::Debug, "Sending content synchronously, Content-Length: {0}", $null, $content.Length)

            $psResponse = Invoke-WebRequest -Uri $request.RequestUri -Method "POST" -Headers $headers -Body $content -UseBasicParsing

            $response = [System.Net.Http.HttpResponseMessage]::new($psResponse.StatusCode)
            $response.Content = [System.Net.Http.StringContent]::new($psResponse.Content, [System.Text.Encoding]::UTF8, "application/json")

            foreach ($header in $psResponse.Headers.GetEnumerator()) {
                $response.Headers.TryAddWithoutValidation($header.Key, $header.Value)
            }

            $HandleResponse.Invoke($this, @($response, $processedEnvelope))
        }

        return [System.Threading.Tasks.Task]::CompletedTask
    }
}
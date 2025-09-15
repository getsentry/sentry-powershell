# Take Sentry's SerializableHttpContent, convert it to a string, and send via PowerShell's Invoke-WebRequest,
# then translate the response back to a .NET HttpResponseMessage.
# There are limited options to perform synchronous operations in Windows PowerShell 5.1 on .NET 4.6, so this is a workaround.
class SynchronousTransport : Sentry.Http.HttpTransportBase, Sentry.Extensibility.ITransport
{
    hidden [Sentry.Extensibility.IDiagnosticLogger] $logger
    hidden [System.Reflection.MethodInfo] $ProcessEnvelope
    hidden [System.Reflection.MethodInfo] $CreateRequest
    hidden [System.Reflection.MethodInfo] $SerializeToStream

    SynchronousTransport([Sentry.SentryOptions] $options) : base($options)
    {
        $this.logger = $options.DiagnosticLogger
        if ($null -eq $this.logger)
        {
            $this.logger = Get-Variable -Scope script -Name SentryPowerShellDiagnosticLogger -ValueOnly -ErrorAction SilentlyContinue
        }

        # These are internal methods, so we need to use reflection to access them.
        try 
        {
            $instanceMethod = [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public;
            
            # Try to get the ProcessEnvelope method
            $this.ProcessEnvelope = [Sentry.Http.HttpTransportBase].GetMethod('ProcessEnvelope', $instanceMethod)
            if ($null -eq $this.ProcessEnvelope)
            {
                throw "ProcessEnvelope method not found on HttpTransportBase"
            }

            # Try to get the CreateRequest method
            $this.CreateRequest = [Sentry.Http.HttpTransportBase].GetMethod('CreateRequest', $instanceMethod)
            if ($null -eq $this.CreateRequest)
            {
                throw "CreateRequest method not found on HttpTransportBase"
            }

            # Try to get the EnvelopeHttpContent type and SerializeToStream method
            $EnvelopeHttpContentType = [Sentry.SentrySdk].Assembly.GetType('Sentry.Internal.Http.EnvelopeHttpContent')
            if ($null -eq $EnvelopeHttpContentType)
            {
                throw "EnvelopeHttpContent type not found"
            }

            # Look for SerializeToStream with correct parameters
            $streamType = [System.IO.Stream]
            $transportContextType = [System.Net.TransportContext]
            $cancellationTokenType = [System.Threading.CancellationToken]
            
            # Try to find the synchronous version: SerializeToStream(Stream, TransportContext, CancellationToken)
            $parameterTypes = @($streamType, $transportContextType, $cancellationTokenType)
            $this.SerializeToStream = $EnvelopeHttpContentType.GetMethod('SerializeToStream', $instanceMethod, $null, $parameterTypes, $null)
            
            if ($null -eq $this.SerializeToStream)
            {
                throw "SerializeToStream method not found on EnvelopeHttpContent"
            }
        }
        catch
        {
            if ($null -ne $this.logger)
            {
                $this.logger.Log([Sentry.SentryLevel]::Warning, 'Failed to initialize reflection methods for SynchronousTransport: {0}', $_.Exception, @())
            }
            throw
        }
    }

    [System.Threading.Tasks.Task] SendEnvelopeAsync([Sentry.Protocol.Envelopes.Envelope] $envelope, [System.Threading.CancellationToken]$cancellationToken = [System.Threading.CancellationToken]::None)
    {
        try
        {
            $processedEnvelope = $this.ProcessEnvelope.Invoke($this, @($envelope))
            if ($processedEnvelope.Items.count -gt 0)
            {
                $request = $this.CreateRequest.Invoke($this, @($processedEnvelope))

                $headers = @{}
                foreach ($header in $request.Headers)
                {
                    $Key = $header.Key
                    $Value = $header.Value.Trim() -join ', '
                    $headers[$Key] = $Value
                }

                $memoryStream = [System.IO.MemoryStream]::new()
                # Call SerializeToStream with the correct parameters: (Stream, TransportContext, CancellationToken)
                $this.SerializeToStream.Invoke($request.Content, @($memoryStream, $null, $cancellationToken))
                $memoryStream.Position = 0

                if ($null -ne $this.logger)
                {
                    $this.logger.Log([Sentry.SentryLevel]::Debug, 'Sending content synchronously, Content-Length: {0}', $null, $memoryStream.Length)
                }

                $ProgressPreference = 'SilentlyContinue'
                $psResponse = Invoke-WebRequest -Uri $request.RequestUri -Method $request.Method.Method -Headers $headers -Body $memoryStream -UseBasicParsing

                $response = [System.Net.Http.HttpResponseMessage]::new($psResponse.StatusCode)
                $contentType = $psResponse.Headers['Content-Type']
                if ($null -eq $contentType)
                {
                    $contentType = 'application/json'
                }
                $response.Content = [System.Net.Http.StringContent]::new($psResponse.Content, [System.Text.Encoding]::UTF8, $contentType)

                foreach ($header in $psResponse.Headers.GetEnumerator())
                {
                    $response.Headers.TryAddWithoutValidation($header.Key, $header.Value)
                }

                $this.HandleResponse($response, $processedEnvelope)
            }
        }
        catch
        {
            if ($null -ne $this.logger)
            {
                $this.logger.Log([Sentry.SentryLevel]::Error, 'Failed to send envelope: {0}', $_.Exception, @())
            }
            throw
        }

        return [System.Threading.Tasks.Task]::CompletedTask
    }
}

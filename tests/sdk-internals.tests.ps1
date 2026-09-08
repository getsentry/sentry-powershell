# Reflection lookups fail silently, so pin the SDK internals the module depends on. A dependency bump that moves
# one of these must fail here rather than at send time.

BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    . "$PSScriptRoot/../modules/Sentry/private/SynchronousTransport.ps1"

    $instanceFlags = [System.Reflection.BindingFlags]::Instance + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public
    $staticFlags = [System.Reflection.BindingFlags]::Static + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public

    function Get-SentryInternalType([string] $name) {
        return [Sentry.SentrySdk].Assembly.GetType($name)
    }

    function Should-BeMethod($method, [string] $returnType, [string[]] $parameterTypes) {
        $method | Should -Not -BeNullOrEmpty
        $method.ReturnType.FullName | Should -Be $returnType
        ($method.GetParameters() | ForEach-Object { $_.ParameterType.FullName }) | Should -Be $parameterTypes
    }
}

Describe 'Sentry SDK internals used by SynchronousTransport' {
    It 'HttpTransportBase.ProcessEnvelope' {
        $method = [Sentry.Http.HttpTransportBase].GetMethod('ProcessEnvelope', $instanceFlags)
        Should-BeMethod $method 'Sentry.Protocol.Envelopes.Envelope' @('Sentry.Protocol.Envelopes.Envelope')
    }

    It 'HttpTransportBase.CreateRequest' {
        $method = [Sentry.Http.HttpTransportBase].GetMethod('CreateRequest', $instanceFlags)
        Should-BeMethod $method 'System.Net.Http.HttpRequestMessage' @('Sentry.Protocol.Envelopes.Envelope')
    }

    It 'HttpTransportBase.HandleResponse' {
        $method = [Sentry.Http.HttpTransportBase].GetMethod('HandleResponse', $instanceFlags)
        Should-BeMethod $method 'System.Void' @('System.Net.Http.HttpResponseMessage', 'Sentry.Protocol.Envelopes.Envelope')
    }

    It 'Sentry.Internal.Http.EnvelopeHttpContent' {
        Get-SentryInternalType 'Sentry.Internal.Http.EnvelopeHttpContent' | Should -Not -BeNullOrEmpty
    }

    It 'EnvelopeHttpContent.SerializeToStream' {
        $type = Get-SentryInternalType 'Sentry.Internal.Http.EnvelopeHttpContent'
        $method = $type.GetMethod('SerializeToStream', $instanceFlags)
        Should-BeMethod $method 'System.Void' @('System.IO.Stream', 'System.Net.TransportContext', 'System.Threading.CancellationToken')
    }
}

Describe 'Sentry SDK internals used by Get-CurrentOptions' {
    It 'SentrySdk.CurrentOptions' {
        $property = [Sentry.SentrySdk].GetProperty('CurrentOptions', $staticFlags)
        $property | Should -Not -BeNullOrEmpty
        $property.PropertyType.FullName | Should -Be 'Sentry.SentryOptions'
    }
}

Describe 'SynchronousTransport' {
    It 'resolves every internal member it needs' {
        # The constructor does all of the above lookups and throws on any that fail.
        $options = [Sentry.SentryOptions]::new()
        $options.Dsn = 'https://key@127.0.0.1/1'
        { [SynchronousTransport]::new($options) } | Should -Not -Throw
    }
}

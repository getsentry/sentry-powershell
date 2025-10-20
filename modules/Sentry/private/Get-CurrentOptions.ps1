function Get-CurrentOptions {
    $bindingFlags = [System.Reflection.BindingFlags]::Static + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public
    $currentOptionsProperty = [Sentry.SentrySdk].GetProperty('CurrentOptions', $bindingFlags)
    if ($null -eq $currentOptionsProperty) {
        return $null
    }

    [Sentry.SentryOptions] $options = $currentOptionsProperty.GetValue($null)
    return $options
}

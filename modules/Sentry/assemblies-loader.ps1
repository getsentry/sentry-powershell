. (Join-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private') 'Get-SentryAssembliesDirectory.ps1')

$dir = Get-SentryAssembliesDirectory

# Check if the assembly is already loaded.
$type = 'Sentry.SentrySdk' -as [type]
if ($type) {
    $loadedAsssembly = $type.Assembly
    $expectedAssembly = [Reflection.Assembly]::LoadFile((Join-Path $dir 'Sentry.dll'))

    if ($loadedAsssembly.ToString() -ne $expectedAssembly.ToString()) {
        throw "Sentry assembly is already loaded but it's not the expected version.
        Found:    ($loadedAsssembly), location: $($loadedAsssembly.Location)
        Expected: ($expectedAssembly), location: $($expectedAssembly.Location)"
    } else {
        Write-Debug "Sentry assembly is already loaded and at the expected version ($($expectedAssembly.GetName().Version)"
    }
} else {
    Write-Debug "Loading assemblies from $($dir):"
    Get-ChildItem -Path $dir -Filter '*.dll' | ForEach-Object {
        Write-Debug "Loading assembly: $($_.Name)"
        [Reflection.Assembly]::LoadFrom($_.FullName) | Write-Debug
    }
}

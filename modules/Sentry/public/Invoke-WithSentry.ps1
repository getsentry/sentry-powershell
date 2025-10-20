. "$publicDir/Out-Sentry.ps1"

function Invoke-WithSentry {
    param(
        [scriptblock]
        $ScriptBlock
    )

    try {
        & $ScriptBlock
    } catch {
        $_ | Out-Sentry
        throw
    }
}

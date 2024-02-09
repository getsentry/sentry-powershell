param([string] $action, [string] $value)

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

$repo = 'https://github.com/getsentry/sentry-dotnet'
$currentVersion = '4.0.3'

switch ($action)
{
    'get-version'
    {
        $currentVersion
    }
    'get-repo'
    {
        $repo
    }
    'set-version'
    {
        $content = Get-Content $PSCommandPath
        $newContent = $content.Replace("`$currentVersion = '$currentVersion'", "`$currentVersion = '$value'")
        if (($content -eq $newContent) -and ("$currentVersion" -ne "$value"))
        {
            throw "Failed to update version in $PSCommandPath - the new content is the same"
        }
        $newContent | Out-File $PSCommandPath
    }
    Default { throw "Unknown action $action" }
}

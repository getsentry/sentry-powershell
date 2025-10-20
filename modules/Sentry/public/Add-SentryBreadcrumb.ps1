function Add-SentryBreadcrumb {
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [string] $Message,

        [string] $Category = $null,
        [string] $Type = $null,
        [hashtable] $Data = $null,
        [Sentry.BreadcrumbLevel] $Level = [Sentry.BreadcrumbLevel]::Info)

    begin {
        if ($null -eq $Data) {
            $DataDict = $null
        } else {
            $DataDict = [System.Collections.Generic.Dictionary[string, string]]::new()
            $Data.Keys | ForEach-Object { $DataDict.Add($_, $Data[$_]) }
        }
    }
    process {
        [Sentry.SentrySdk]::AddBreadcrumb($Message, $Category, $Type, $DataDict, $Level)
    }
}

function Edit-SentryScope {
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScopeSetup
    )

    process {
        [Sentry.SentrySdk]::ConfigureScope([System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)
                # Execute the script block in the caller's scope (nothing to do $scope) & set the automatic $_ variable to the $scope object.
                $scope | ForEach-Object $ScopeSetup
            })
    }
}

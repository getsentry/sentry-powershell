class ScopeIntegration : Sentry.Integrations.ISdkIntegration {
    Register([Sentry.IHub] $hub, [Sentry.SentryOptions] $options) {
        $hub.ConfigureScope([System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)

                $scope.Sdk.Name = 'sentry.dotnet.powershell'
                $scope.Sdk.Version = $moduleInfo.ModuleVersion
                $scope.Sdk.AddPackage("ps:$($scope.Sdk.Name)", $scope.Sdk.Version)

                if ($PSVersionTable.PSEdition -eq 'Core') {
                    $scope.Contexts.Runtime.Name = 'PowerShell'
                } else {
                    $scope.Contexts.Runtime.Name = 'Windows PowerShell'
                }
                $scope.Contexts.Runtime.Version = $PSVersionTable.PSVersion.ToString()

                $netRuntime = [Sentry.PlatformAbstractions.SentryRuntime]::Current
                $scope.Contexts['runtime.net'] = [Sentry.Protocol.Runtime]::new()
                $scope.Contexts['runtime.net'].Name = $netRuntime.Name
                $scope.Contexts['runtime.net'].Version = $netRuntime.Version
            });
    }
}

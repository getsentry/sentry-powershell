class ScopeIntegration : Sentry.Integrations.ISdkIntegration
{
    Register([Sentry.IHub] $hub, [Sentry.SentryOptions] $options)
    {
        $hub.ConfigureScope([System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)

                $scope.Sdk.Name = 'sentry.powershell';
                $scope.Sdk.Version = $moduleInfo.ModuleVersion;
                $scope.Sdk.AddPackage("ps:$($scope.Sdk.Name)", $scope.Sdk.Version);
            });
    }
}

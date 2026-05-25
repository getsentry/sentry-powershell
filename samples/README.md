From the root of the repository, run the following commands:

To run the sample make sure you download the dependencies.

```sh
pwsh ./dependencies/download.ps1
```

Then you can run the sample, for example:
```sh
pwsh ./samples/locate-city.ps1 Toronto
```

Or send structured logs to Sentry (see the [Sentry Logs docs](https://docs.sentry.io/platforms/dotnet/logs/)):
```sh
pwsh ./samples/send-logs.ps1
```
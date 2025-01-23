# Contributing

Any contributions are welcome, be it feedback, bug reports, documentation, or code contributions.

## Set up this repo for local development

1. Clone the repository
2. Launch `./scripts/download.ps1' to download the required dependencies.
   You'll also need to do this after a sentry-dotnet SDK update.

## Running tests

We use pester to execute tests. First, you'll need to import the deveopment version of the module.

```powershell
Import-Module ./modules/Sentry/Sentry.psd1
Invoke-Pester
```

Note: changes to the module code you make after the import won't be reflected.
Reimporting the module won't work either.
You'll need to close the shell and import again in a new shell instance.

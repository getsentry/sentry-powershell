<#
.SYNOPSIS
	Prints the geographic location of a city
.DESCRIPTION
	This PowerShell script prints the geographic location of the given city.
.PARAMETER City
	Specifies the city to look for
.EXAMPLE
	PS> ./locate-city.ps1 Paris
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$City = '')

# Import the Sentry module. In your code, you would just use `Import-Module Sentry`.
Import-Module $PSScriptRoot/../modules/Sentry/Sentry.psd1

# Start the Sentry client.
Start-Sentry -Debug {
    $_.Dsn = 'https://eb18e953812b41c3aeb042e666fd3b5c@o447951.ingest.sentry.io/5428537'
    $_.TracesSampleRate = 1.0
}

# Transaction can be started by providing, at minimum, the name and the operation
$transaction = Start-SentryTransaction 'transaction-name' 'transaction-operation'

try
{
    $span = $transaction.StartChild('wait for input')
    if ($City -eq '' ) { $City = Read-Host 'Enter the city name' }
    $span.Finish()

    $span = $transaction.StartChild('read CSV')
    Write-Progress 'Reading worldcities.csv...'
    $Table = Import-Csv "$PSScriptRoot/../data/worldcities.csv"
    $span.Finish()

    $span = $transaction.StartChild('search')
    $FoundOne = 0
    foreach ($Row in $Table)
    {
        if ($Row.city -eq $City)
        {
            $FoundOne = 1
            $Country = $Row.country
            $Region = $Row.admin_name
            $Lat = $Row.lat
            $Long = $Row.lng
            $Population = $Row.population
            Write-Host "* $City ($Country, $Region, population $Population) is at $Lat°N, $Long°W"
        }
    }
    $span.Finish()

    if ($FoundOne)
    {
        exit 0 # success
    }
    Write-Error "City $City not found"
    exit 1
}
catch
{
    $_ | Out-Sentry
    "⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
}
finally
{
    # Mark the transaction as finished and send it to Sentry
    $transaction.Finish()
}

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

$propsFileContent = Get-Content "$PSScriptRoot/sentry-dotnet.properties" -Raw
$targetDir = "$PSScriptRoot/downloads"
New-Item $targetDir -ItemType Directory -Force | Out-Null
$moduleDir = "$PSScriptRoot/../module"
$libDir = "$moduleDir/lib"
$targetPropsFile = "$libDir/sentry-dotnet.properties"
if ((Get-Content $targetPropsFile -Raw -ErrorAction SilentlyContinue) -eq $propsFileContent)
{
    Write-Debug "No changes detected in $targetPropsFile, skipping download"
}
else
{

    $conf = ($propsFileContent | ConvertFrom-StringData)
    $sourceUrl = "$($conf.repo)/releases/download/$($conf.version)/Sentry.$($conf.version).nupkg"
    $sourceZip = "$targetDir/sentry.zip"

    Write-Output "Downloading $sourceUrl"
    Invoke-WebRequest $sourceUrl -OutFile $sourceZip
    $archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)

    function extract([string] $fileToExtract, [string] $extractDir)
    {
        if ($file = $archive.Entries.Where(({ $_.FullName -eq $fileToExtract })))
        {
            $file = $file[0]
            $destinationFile = Join-Path $extractDir $file.Name

            Write-Output "Extracting $fileToExtract to $destinationFile"
            New-Item $extractDir -ItemType Directory -Force | Out-Null
            Remove-Item $destinationFile -Force -ErrorAction SilentlyContinue | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($file, $destinationFile)
        }
        else
        {
            throw "File not found in ZIP: $fileToExtract"
        }
    }

    try
    {
        extract 'lib/net8.0/Sentry.dll' "$libDir/net8.0"
        extract 'lib/net6.0/Sentry.dll' "$libDir/net6.0"
        extract 'lib/netstandard2.0/Sentry.dll' "$libDir/netstandard2.0"
        extract 'lib/net462/Sentry.dll' "$libDir/net462"
    }
    finally
    {
        $archive.Dispose()
    }

    $propsFileContent | Out-File -NoNewline $targetPropsFile
}

Import-Module "$moduleDir/Sentry.psd1" | Out-Null


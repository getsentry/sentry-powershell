Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

$downloadDir = "$PSScriptRoot/dependencies/downloads"
$propsDir = "$PSScriptRoot/dependencies"
$moduleDir = "$PSScriptRoot/../module"
$libDir = "$moduleDir/lib"

New-Item $libDir -ItemType Directory -Force | Out-Null

function CheckAssemblyVersion([string] $libFile, [string] $assemblyVersion)
{
    $assembly = [Reflection.Assembly]::LoadFile($libFile)
    if ($assembly.GetName().Version.ToString() -ne $assemblyVersion)
    {
        throw "Dependency $libFile has different assembly version ($($assembly.GetName().Version)) than expected ($assemblyVersion)"
    }
}

function Download([string] $dependency, [string] $sourceTFM, [string] $targetTFM = $null)
{
    $targetTFM = "$targetTFM" -eq '' ? $sourceTFM : $targetTFM
    New-Item "$libDir/$targetTFM" -ItemType Directory -Force | Out-Null

    $props = (Get-Content "$propsDir/$dependency.properties" -Raw | ConvertFrom-StringData)
    $assemblyVersion = $props.ContainsKey('assemblyVersion') ? $props.assemblyVersion : "$($props.version).0"

    $targetLibFile = "$libDir/$targetTFM/$dependency.dll"
    $targetVersionFile = "$libDir/$targetTFM/$dependency.version"

    if ((Test-Path $targetLibFile) -and ((Get-Content $targetVersionFile -Raw -ErrorAction SilentlyContinue) -eq $assemblyVersion))
    {
        try
        {
            CheckAssemblyVersion $targetLibFile $assemblyVersion
            return
        }
        catch
        {
            Write-Warning "$_, downloading again".
        }
    }

    Remove-Item $targetLibFile -Force -ErrorAction SilentlyContinue
    Remove-Item $targetVersionFile -Force -ErrorAction SilentlyContinue

    $archiveName = "$($dependency.ToLower()).$($props.version).nupkg"
    $archiveFile = "$downloadDir/$archiveName"

    if (Test-Path $archiveFile)
    {
        Write-Debug "Archive $archiveFile already exists, skipping download"
    }
    else
    {
        Write-Output "Downloading $archiveName"
        $sourceUrl = "https://globalcdn.nuget.org/packages/$archiveName"
        Invoke-WebRequest $sourceUrl -OutFile $archiveFile
    }

    $archive = [IO.Compression.ZipFile]::OpenRead($archiveFile)

    function extract([string] $fileToExtract, [string] $extractDir)
    {
        if ($file = $archive.Entries.Where(({ $_.FullName -eq $fileToExtract })))
        {
            Write-Output "Extracting $fileToExtract to $targetLibFile"
            New-Item $extractDir -ItemType Directory -Force | Out-Null
            Remove-Item targetLibFile -Force -ErrorAction SilentlyContinue | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($file[0], $targetLibFile)
        }
        else
        {
            throw "File not found in ZIP: $fileToExtract"
        }
    }

    try
    {
        extract "lib/$sourceTFM/$dependency.dll" "$libDir/$targetTFM"
    }
    finally
    {
        $archive.Dispose()
    }

    CheckAssemblyVersion $targetLibFile $assemblyVersion
    $assemblyVersion | Out-File -NoNewline $targetVersionFile
}

Download 'Sentry' 'net8.0'
Download 'Sentry' 'net6.0'
Download 'Sentry' 'netstandard2.0'
Download 'Sentry' 'net462'
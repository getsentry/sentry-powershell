. "$PSScriptRoot/../tools/settings.ps1"
$downloadDir = "$PSScriptRoot/downloads"
$propsDir = "$PSScriptRoot"
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

function Download([string] $dependency, [string] $TFM, [string] $targetTFM = $null)
{
    $targetTFM = "$targetTFM" -eq '' ? $TFM : $targetTFM
    New-Item "$libDir/$targetTFM" -ItemType Directory -Force | Out-Null

    $props = (Get-Content "$propsDir/$dependency.properties" -Raw | ConvertFrom-StringData)
    $assemblyVersion = $props.ContainsKey('assemblyVersion') ? $props.assemblyVersion : "$($props.version).0"

    $targetLibFile = "$libDir/$targetTFM/$dependency.dll"
    $targetVersionFile = "$libDir/$targetTFM/$dependency.version"
    $targetLicenseFile = "$libDir/$targetTFM/$dependency.license"

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

    if (Test-Path $targetLibFile)
    {
        Remove-Item $targetLibFile -Force
    }
    if (Test-Path $targetVersionFile)
    {
        Remove-Item $targetVersionFile -Force
    }
    if (Test-Path $targetLicenseFile)
    {
        Remove-Item $targetLicenseFile -Force
    }

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

    function extract([string] $fileToExtract, [string] $targetFile)
    {
        if ($file = $archive.Entries.Where(({ $_.FullName -eq $fileToExtract })))
        {
            Write-Output "Extracting $fileToExtract to $targetFile"
            [IO.Compression.ZipFileExtensions]::ExtractToFile($file[0], $targetFile)
        }
        else
        {
            throw "File not found in ZIP: $fileToExtract"
        }
    }

    try
    {
        extract "lib/$TFM/$dependency.dll" $targetLibFile
        if ($props.ContainsKey('licenseFile'))
        {
            extract $props.licenseFile $targetLicenseFile
        }
        else
        {
            $props.license | Out-File -NoNewline $targetLicenseFile
        }
    }
    finally
    {
        $archive.Dispose()
    }

    CheckAssemblyVersion $targetLibFile $assemblyVersion
    $assemblyVersion | Out-File -NoNewline $targetVersionFile
}

Download -Dependency 'Sentry' -TFM 'net8.0'
Download -Dependency 'Sentry' -TFM 'net6.0'
Download -Dependency 'Sentry' -TFM 'netstandard2.0'
Download -Dependency 'Sentry' -TFM 'net462'

Download -Dependency 'System.Text.Json' -TFM 'net461' -TargetTFM 'net462'
Download -Dependency 'Microsoft.Bcl.AsyncInterfaces' -TFM 'net461' -TargetTFM 'net462'
Download -Dependency 'System.Threading.Tasks.Extensions' -TFM 'net461' -TargetTFM 'net462'

Download -Dependency 'System.Text.Json' -TFM 'netstandard2.0'

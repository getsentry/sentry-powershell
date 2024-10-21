. "$PSScriptRoot/../scripts/settings.ps1"
$downloadDir = "$PSScriptRoot/downloads"
$propsDir = "$PSScriptRoot"
$moduleDir = "$PSScriptRoot/../modules/Sentry"
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

function Download([string] $dependency, [string] $TFM, [string] $targetTFM = $null, [string] $assemblyVersion = $null)
{
    $targetTFM = "$targetTFM" -eq '' ? $TFM : $targetTFM
    New-Item "$libDir/$targetTFM" -ItemType Directory -Force | Out-Null

    $props = (Get-Content "$propsDir/$dependency.properties" -Raw | ConvertFrom-StringData)

    if ("$assemblyVersion" -eq '')
    {
        $assemblyVersion = $props.ContainsKey('assemblyVersion') ? $props.assemblyVersion : "$($props.version).0"
    }

    $package = $props.ContainsKey('package') ? $props.package : $dependency
    $targetLibFile = "$libDir/$targetTFM/$dependency.dll"
    $targetVersionFile = "$libDir/$targetTFM/$dependency.version"
    $targetLicenseFile = "$libDir/$targetTFM/$dependency.license"

    if ((Test-Path $targetLibFile) -and ((Get-Content $targetVersionFile -Raw -ErrorAction SilentlyContinue) -eq $assemblyVersion))
    {
        try
        {
            CheckAssemblyVersion $targetLibFile $assemblyVersion
            Write-Debug "Dependency $targetLibFile already exists and has the expected assembly version ($assemblyVersion), skipping."
            return
        }
        catch
        {
            Write-Warning "$_, downloading again"
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

    $archiveName = "$($package.ToLower()).$($props.version).nupkg"
    $archiveFile = "$downloadDir/$archiveName"

    if (Test-Path $archiveFile)
    {
        Write-Debug "Archive $archiveFile already exists, skipping download"
    }
    else
    {
        $sourceUrl = "https://globalcdn.nuget.org/packages/$archiveName"
        Write-Output "Downloading $sourceUrl"
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
        extract "lib/$TFM/$package.dll" $targetLibFile
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
Download -Dependency 'Sentry' -TFM 'net462'

# You can see the list of dependencies that are actually used in sentry-dotnet/src/Sentry/bin/Debug/net462
# As for the versions in use, check the sentry package on nuget.org.
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'Microsoft.Bcl.AsyncInterfaces'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Buffers'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Collections.Immutable'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Memory'
Download -TFM 'net46' -TargetTFM 'net462' -Dependency 'System.Numerics.Vectors'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Reflection.Metadata'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Runtime.CompilerServices.Unsafe.4'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Runtime.CompilerServices.Unsafe.6'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Text.Encodings.Web'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Text.Json'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.Threading.Tasks.Extensions'
Download -TFM 'net461' -TargetTFM 'net462' -Dependency 'System.ValueTuple'

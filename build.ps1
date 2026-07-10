param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = $PSScriptRoot
$pubspecPath = Join-Path $repositoryRoot 'pubspec.yaml'
$pubspecContent = Get-Content -Raw -LiteralPath $pubspecPath
$versionMatch = [regex]::Match(
    $pubspecContent,
    '(?m)^version:\s*(?<version>\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)(?:\+(?<build>\d+))?\s*$'
)

if (-not $versionMatch.Success) {
    throw 'A valid version field was not found in pubspec.yaml.'
}

$version = $versionMatch.Groups['version'].Value
$releaseDirectory = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
$executablePath = Join-Path $releaseDirectory 'ReTSM.exe'
$distDirectory = Join-Path $repositoryRoot 'dist'
$archivePath = Join-Path $distDirectory "ReTSM-Windows-x64-v$version.zip"
$installerBaseName = "ReTSM-Setup-v$version"
$installerPath = Join-Path $distDirectory "$installerBaseName.exe"
$checksumPath = Join-Path $distDirectory 'SHA256SUMS.txt'
$installerScript = Join-Path $repositoryRoot 'installer\re_tsm.iss'

Push-Location $repositoryRoot
try {
    if (-not $SkipFlutterBuild) {
        Write-Host "Building ReTSM v$version..."
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with exit code $LASTEXITCODE."
        }
    }

    if (-not (Test-Path -LiteralPath $executablePath)) {
        throw "Build output was not found at '$executablePath'."
    }

    New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
    foreach ($outputPath in @($archivePath, $installerPath, $checksumPath)) {
        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force
        }
    }

    Write-Host 'Creating portable ZIP...'
    Compress-Archive `
        -Path (Join-Path $releaseDirectory '*') `
        -DestinationPath $archivePath `
        -CompressionLevel Optimal

    $isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $isccCandidates = @(
        $isccCommand.Source
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe')
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $isccPath = $isccCandidates | Select-Object -First 1

    if (-not $isccPath) {
        throw @"
Inno Setup 6 or 7 was not found. Install it from https://jrsoftware.org/isdl.php
and ensure ISCC.exe is on PATH or in the default installation directory.
"@
    }

    Write-Host 'Creating Inno Setup installer...'
    $compilerArguments = @(
        "/DAppVersion=$version"
        "/DSourceDir=$releaseDirectory"
        "/DOutputDir=$distDirectory"
        "/DOutputBaseFilename=$installerBaseName"
        $installerScript
    )
    & $isccPath @compilerArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-Path -LiteralPath $installerPath)) {
        throw "Installer output was not found at '$installerPath'."
    }

    $checksumLines = foreach ($outputPath in @($archivePath, $installerPath)) {
        $fileName = Split-Path -Leaf $outputPath
        $checksum = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash.ToLowerInvariant()
        "$checksum  $fileName"
    }
    $checksumLines | Set-Content -LiteralPath $checksumPath -Encoding utf8

    Write-Host 'Build complete:'
    Write-Host "  Portable ZIP: $archivePath"
    Write-Host "  Installer:    $installerPath"
    Write-Host "  Checksums:    $checksumPath"
} finally {
    Pop-Location
}

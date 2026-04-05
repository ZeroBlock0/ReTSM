$ErrorActionPreference = 'Stop'
Write-Host "Building Flutter app..."
flutter build windows

$releaseDir = Resolve-Path "build\windows\x64\runner\Release"
$exePath = Join-Path $releaseDir "ReTSM.exe"
$outputExe = Join-Path (Get-Location) "ReTSM-Portable.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "Build failed, exe not found."
}

Write-Host "Generating EVB XML recursively..."

function Get-EvbXml {
    param([string]$Path, [int]$Indent)
    $xml = ""
    $items = Get-ChildItem -Path $Path
    $pad = "".PadLeft($Indent)
    foreach ($item in $items) {
        if ($item.FullName -eq $exePath) { continue }

        if ($item.PSIsContainer) {
            $xml += "$pad<File>`n"
            $xml += "$pad  <Type>3</Type>`n"
            $xml += "$pad  <Name>$([System.Security.SecurityElement]::Escape($item.Name))</Name>`n"
            $xml += "$pad  <Action>0</Action>`n"
            $xml += "$pad  <OverwriteDateTime>false</OverwriteDateTime>`n"
            $xml += "$pad  <OverwriteAttributes>false</OverwriteAttributes>`n"
            $xml += "$pad  <HideFromDialogs>0</HideFromDialogs>`n"
            $xml += "$pad  <Files>`n"
            $xml += Get-EvbXml -Path $item.FullName -Indent ($Indent + 4)
            $xml += "$pad  </Files>`n"
            $xml += "$pad</File>`n"
        } else {
            $xml += "$pad<File>`n"
            $xml += "$pad  <Type>2</Type>`n"
            $xml += "$pad  <Name>$([System.Security.SecurityElement]::Escape($item.Name))</Name>`n"
            $xml += "$pad  <File>$([System.Security.SecurityElement]::Escape($item.FullName))</File>`n"
            $xml += "$pad  <ActiveX>false</ActiveX>`n"
            $xml += "$pad  <ActiveXInstall>false</ActiveXInstall>`n"
            $xml += "$pad  <Action>0</Action>`n"
            $xml += "$pad  <OverwriteDateTime>false</OverwriteDateTime>`n"
            $xml += "$pad  <OverwriteAttributes>false</OverwriteAttributes>`n"
            $xml += "$pad  <PassCommandLine>false</PassCommandLine>`n"
            $xml += "$pad  <HideFromDialogs>0</HideFromDialogs>`n"
            $xml += "$pad</File>`n"
        }
    }
    return $xml
}

$dynamicFiles = Get-EvbXml -Path $releaseDir -Indent 14

$evbTemplate = @"
<?xml version="1.0" encoding="windows-1251"?>
<>
  <InputFile>$exePath</InputFile>
  <OutputFile>$outputExe</OutputFile>
  <Files>
    <Enabled>true</Enabled>
    <DeleteExtractedOnExit>false</DeleteExtractedOnExit>
    <CompressFiles>true</CompressFiles>
    <Files>
      <File>
        <Type>3</Type>
        <Name>%DEFAULT FOLDER%</Name>
        <Action>0</Action>
        <OverwriteDateTime>false</OverwriteDateTime>
        <OverwriteAttributes>false</OverwriteAttributes>
        <HideFromDialogs>0</HideFromDialogs>
        <Files>
$dynamicFiles
        </Files>
      </File>
    </Files>
  </Files>
  <Registries>
    <Enabled>false</Enabled>
  </Registries>
  <Packaging>
    <Enabled>false</Enabled>
  </Packaging>
  <Options>
    <ShareVirtualSystem>false</ShareVirtualSystem>
    <MapExecutableWithTemporaryFile>true</MapExecutableWithTemporaryFile>
    <AllowRunningOfVirtualExeFiles>true</AllowRunningOfVirtualExeFiles>
  </Options>
</>
"@

Set-Content -Path "build_dynamic.evb" -Value $evbTemplate -Encoding UTF8

Write-Host "Packing with Enigma Virtual Box..."
$evbConsole = "C:\Program Files (x86)\Enigma Virtual Box\enigmavbconsole.exe"
if (Test-Path $evbConsole) {
    & $evbConsole "build_dynamic.evb"
    Write-Host "Done! Output: $outputExe"
} else {
    Write-Error "Enigma Virtual Box console not found at $evbConsole"
}

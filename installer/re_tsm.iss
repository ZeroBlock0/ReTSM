#ifndef AppVersion
  #error AppVersion must be provided by build.ps1
#endif

#ifndef SourceDir
  #error SourceDir must be provided by build.ps1
#endif

#ifndef OutputDir
  #error OutputDir must be provided by build.ps1
#endif

#ifndef OutputBaseFilename
  #error OutputBaseFilename must be provided by build.ps1
#endif

[Setup]
AppId={{B6EC0408-DB5C-475F-8B36-CEEB25ED5FFD}
AppName=ReTSM
AppVersion={#AppVersion}
AppVerName=ReTSM {#AppVersion}
AppPublisher=ZeroBlock0
AppPublisherURL=https://github.com/ZeroBlock0/ReTSM
AppSupportURL=https://github.com/ZeroBlock0/ReTSM/issues
AppUpdatesURL=https://github.com/ZeroBlock0/ReTSM/releases
DefaultDirName={localappdata}\Programs\ReTSM
DefaultGroupName=ReTSM
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ReTSM.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ReTSM"; Filename: "{app}\ReTSM.exe"
Name: "{autodesktop}\ReTSM"; Filename: "{app}\ReTSM.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ReTSM.exe"; Description: "{cm:LaunchProgram,ReTSM}"; Flags: nowait postinstall skipifsilent

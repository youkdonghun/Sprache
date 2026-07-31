#ifndef MyAppVersion
  #error MyAppVersion must be supplied by build-windows-installer.ps1
#endif

#ifndef ReleaseDir
  #error ReleaseDir must be supplied by build-windows-installer.ps1
#endif

#ifndef InstallerOutputDir
  #error InstallerOutputDir must be supplied by build-windows-installer.ps1
#endif

#define MyAppName "Sprache"
#define MyAppExeName "sprache.exe"

[Setup]
AppId={{07105448-EEAE-4779-8358-BE6573C587FC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=Sprache
AppPublisherURL=https://github.com/youkdonghun/Sprache
AppSupportURL=https://github.com/youkdonghun/Sprache/issues
AppUpdatesURL=https://github.com/youkdonghun/Sprache/releases
DefaultDirName={localappdata}\Programs\Sprache
DefaultGroupName=Sprache
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#InstallerOutputDir}
OutputBaseFilename=Sprache-Windows-Setup-{#MyAppVersion}-google-x64
SetupIconFile=..\..\apps\client\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#MyAppVersion}.0
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoDescription=Sprache language and general study workspace installer

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Sprache"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Sprache"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,Sprache}"; Flags: nowait postinstall skipifsilent

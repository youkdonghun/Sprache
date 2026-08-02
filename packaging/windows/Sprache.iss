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
ChangesAssociations=yes
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

[Registry]
Root: HKCU; Subkey: "Software\Classes\Sprache.Import"; ValueType: string; ValueName: ""; ValueData: "Sprache 학습 자료"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Sprache.Import\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCU; Subkey: "Software\Classes\Sprache.Import\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\.csv\OpenWithProgids"; ValueType: string; ValueName: "Sprache.Import"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.tsv\OpenWithProgids"; ValueType: string; ValueName: "Sprache.Import"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.xlsx\OpenWithProgids"; ValueType: string; ValueName: "Sprache.Import"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.json\OpenWithProgids"; ValueType: string; ValueName: "Sprache.Import"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.jsonl\OpenWithProgids"; ValueType: string; ValueName: "Sprache.Import"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe\SupportedTypes"; ValueType: string; ValueName: ".csv"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe\SupportedTypes"; ValueType: string; ValueName: ".tsv"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe\SupportedTypes"; ValueType: string; ValueName: ".xlsx"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe\SupportedTypes"; ValueType: string; ValueName: ".json"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe\SupportedTypes"; ValueType: string; ValueName: ".jsonl"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\sprache.exe\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\sprache"; ValueType: string; ValueName: ""; ValueData: "URL:Sprache Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\sprache"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\sprache\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCU; Subkey: "Software\Classes\sprache\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,Sprache}"; Flags: nowait postinstall skipifsilent

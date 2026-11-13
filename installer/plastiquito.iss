; Instalador de Plastiquito: Pop Everything (solo para playtests y demos fuera de Steam).
; Lo compila tools/build.sh o tools/build.ps1, que pasan estos parámetros:
;   iscc /DAppVersion=0.1.0 /DBuildDir=<carpeta con Plastiquito.exe> /DOutDir=<salida> /DRepoDir=<raíz del repo> installer\plastiquito.iss

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\builds\" + AppVersion + "\windows"
#endif
#ifndef OutDir
  #define OutDir "..\builds\" + AppVersion
#endif
#ifndef RepoDir
  #define RepoDir ".."
#endif

[Setup]
AppId={{6D2A9C54-3B7E-4F1A-9E58-2C1F7A0B4D93}
AppName=Plastiquito: Pop Everything
AppVersion={#AppVersion}
AppVerName=Plastiquito: Pop Everything {#AppVersion}
AppPublisher=Plastiquito
DefaultDirName={localappdata}\Programs\Plastiquito
DefaultGroupName=Plastiquito
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutDir}
OutputBaseFilename=Plastiquito_{#AppVersion}_setup
SetupIconFile={#RepoDir}\icon.ico
UninstallDisplayIcon={app}\Plastiquito.exe
UninstallDisplayName=Plastiquito: Pop Everything
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\Plastiquito.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Plastiquito"; Filename: "{app}\Plastiquito.exe"
Name: "{autodesktop}\Plastiquito"; Filename: "{app}\Plastiquito.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Plastiquito.exe"; Description: "{cm:LaunchProgram,Plastiquito}"; Flags: nowait postinstall skipifsilent

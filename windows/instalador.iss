; Instalador do app de Windows: um único .exe que instala o app só para o usuário atual, sem pedir administrador.
; Antes de compilar: flutter build windows --release (com o --dart-define da API) e as três DLLs do Visual C++ copiadas
; para build\windows\x64\runner\Release. Depois: ISCC /DVersao=1.3.0 windows\instalador.iss
; O GitHub Actions faz tudo isso em .github/workflows/instalador-windows.yml.

#ifndef Versao
  #define Versao "0.0.0"
#endif
#define Pasta AddBackslash(SourcePath) + "..\build\windows\x64\runner\Release"

#if !FileExists(Pasta + "\rvlabel_app.exe")
  #error Rode antes: flutter build windows --release
#endif
#if !FileExists(Pasta + "\msvcp140.dll") || !FileExists(Pasta + "\vcruntime140.dll") || !FileExists(Pasta + "\vcruntime140_1.dll")
  #error Copie msvcp140.dll, vcruntime140.dll e vcruntime140_1.dll para a pasta Release (veja o README)
#endif

[Setup]
; Não troque o AppId: é ele que faz o Windows reconhecer uma versão nova como atualização da antiga.
AppId={{DC591A33-14CA-4F17-A525-7F47F39C09C1}
AppName=RV Label
AppVersion={#Versao}
AppPublisher=RV Label
VersionInfoVersion={#Versao}
PrivilegesRequired=lowest
; Com PrivilegesRequired=lowest, {autopf} vira %LOCALAPPDATA%\Programs.
DefaultDirName={autopf}\RV Label
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rvlabel_app.exe
OutputDir=..\build\instalador
OutputBaseFilename=rvlabel-app-v{#Versao}-windows-instalador
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Pasta}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\RV Label"; Filename: "{app}\rvlabel_app.exe"
Name: "{autodesktop}\RV Label"; Filename: "{app}\rvlabel_app.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\rvlabel_app.exe"; Description: "{cm:LaunchProgram,RV Label}"; Flags: nowait postinstall skipifsilent

#define MyAppName "SeePDF"
#define MyAppVersion "1.0.0"
#define Year GetDateTimeString('yyyy', '', '');
#define MyAppPublisher "KED Software"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
;AppPublisherURL=https://www.ked.co.za
AppContact=Customer Support Department
AppCopyright=Copyright (C) (#Year) {#MyAppPublisher}
AppSupportPhone=+27 21 532 2351
;AppSupportURL=https://www.ked.co.za
DefaultDirName={commonpf}\KED\SeePDF
DefaultGroupName="KED\SeePDF"
DisableProgramGroupPage=yes
DisableWelcomePage=no
OutputDir=..\Installations
OutputBaseFilename=SeePDFSetup_x-x-x_(32)
SolidCompression=yes
SourceDir=InstallationFiles
SetupIconFile="SeePDF_icon.ico"
UninstallDisplayIcon={app}\SeePDF.exe
UninstallDisplayName={#MyAppName}
Uninstallable=True
;WizardImageFile="Supplementary Files\Side Splash only - InterMet Logo + fade2.bmp"
;WizardSmallImageFile="Supplementary Files\Banner - InterMet Logo Top Right.bmp"

[Files]
Source: "SeePDF.exe"; DestDir: "{app}"
Source: "pdfium.dll"; DestDir: "{app}"

[Run]
Filename: "{app}\SeePDF.exe"; Description: "Launch application"; Flags: postinstall nowait

[Icons]
Name: "{group}\SeePDF"; Filename: "{app}\SeePDF.exe"; Comment: "Music score browser";
Name: "{commonstartup}\SeePDF"; Filename: "{app}\SeePDF.exe"; Comment: "Music score browser";
Name: "{commondesktop}\SeePDF"; Filename: "{app}\SeePDF.exe"; Comment: "Music score browser";

unit Configuration;

interface

uses
  System.IniFiles;

var
  progConfig : TIniFile;
  sAppDataDir : String;

implementation

uses
  System.SysUtils, System.IOUtils,
  FMX.Forms,
  Constants;

initialization
  // Get the directory where all application data is to be kept
  sAppDataDir := TPath.GetPublicPath + PathDelim + ORIGINATOR + PathDelim + PROGRAM_NAME + PathDelim;
  // Ensure that this folder is valid
  if (not DirectoryExists(sAppDataDir)) then
    ForceDirectories(sAppDataDir);
  progConfig := TIniFile.Create(sAppDataDir + 'config.ini');

end.

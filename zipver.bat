SET ZIP_FILE_PREFIX=SeePDF
SET UNITS=DUnits12

@ECHO **** Zipping project source files ****
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" @zipinclude.txt -tzip

@ECHO **** Zipping created and required binaries ****
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" Win32\Debug\*.exe -tzip
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" Win32\Release\*.exe -tzip
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" *.exe -tzip
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" *.dll -tzip

REM Assuming that the source code is in X:\Delphi_???\<Project Name>\
cd ..
@ECHO **** Zipping Delphi units source files ****
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" "%UNITS%\*.pas" -tzip
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" "%UNITS%\*.dfm" -tzip
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" "%UNITS%\*.obj" -tzip
"c:\Program Files\7-Zip\7z" a %~dp0"Versions\%ZIP_FILE_PREFIX%_%1" "%UNITS%\*.txt" -tzip

cd %~dp0

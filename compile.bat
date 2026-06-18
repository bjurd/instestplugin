@echo off
setlocal EnableDelayedExpansion

if "%SOURCEMOD_HOME%"=="" (
	set "SOURCEMOD_HOME=C:\Program Files (x86)\Steam\steamapps\common\Insurgency Dedicated Server\insurgency\addons\sourcemod"
)

set "SPCOMP=%SOURCEMOD_HOME%\scripting\spcomp.exe"
if not exist "%SPCOMP%" (
	echo spcomp.exe not found in "%SPCOMP%"
	exit /b 1
)

set "SRCDIR=source"
set "OUTDIR=plugins"

if not exist "%SRCDIR%" (
	echo "%SRCDIR%" not found
	exit /b 1
)

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

set "ROOT=%CD%\%SRCDIR%"
set "FAILED=0"
set "COUNT=0"

for /r "%ROOT%" %%F in (*.sp) do (
	set "RELPATH=%%F"
	set "RELPATH=!RELPATH:%ROOT%\=!"
	set "OUTFILE=%OUTDIR%\!RELPATH:.sp=.smx!"

	for %%D in ("!OUTFILE!") do if not exist "%%~dpD" mkdir "%%~dpD"

	echo Compiling !RELPATH! ...
	"%SPCOMP%" -i"%SOURCEMOD_HOME%\scripting\include" -o"!OUTFILE!" "%%F"
	if errorlevel 1 (
		set "FAILED=1"
	) else (
		set /a COUNT+=1
	)
)

if "%COUNT%"=="0" (
	echo No shit in "%SRCDIR%".
	exit /b 1
)

if "%FAILED%"=="1" (
	echo.
	echo Epic fail
	exit /b 1
)

echo.
echo Compiled %COUNT%
exit /b 0

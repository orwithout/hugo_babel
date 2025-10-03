@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

set "PCELF_PROJECT_NAME=pcelf.com"
for %%i in ("%~dp0.") do set "PCELF_PROJECT_HOME=%%~fi"
echo %PCELF_PROJECT_HOME% env:
set "PCELF_PROJECT_ENV_HOME=%PCELF_PROJECT_HOME%\nodes\_env"
set "PCELF_ENV_PATHS="
set "PCELF_FINAL_CMD=(cursor . >nul 2>nul) & (where pwsh >nul 2>nul && (pwsh -NoExit -NoLogo) || (powershell -NoExit))"




set "modules_enable=pwsh,vscode,envsync"
set "env_config=%~dp0.env"
set "env_config_example=%PCELF_PROJECT_ENV_HOME%\env.example"


set "env_managed_begin=######## ENV.CMD MANAGED BEGIN ########"
set "env_managed_end=######## ENV.CMD MANAGED END ########"
>"%env_config_example%"  echo %env_managed_begin%
>>"%env_config_example%" echo ######## 这些参数由env.cmd 维护勿手改. # These parameters are maintained by env.cmd and should not be modified manually.
>>"%env_config_example%" echo PCELF_PROJECT_NAME=%PCELF_PROJECT_NAME%
>>"%env_config_example%" echo PCELF_PROJECT_HOME=%PCELF_PROJECT_HOME%
>>"%env_config_example%" echo PCELF_PROJECT_ENV_HOME=%PCELF_PROJECT_ENV_HOME%
goto :main
:: ----------------------------------------------------------------------
:: Subroutines (defined early so calls always resolve)
:: ----------------------------------------------------------------------
:set_var
    set "%~1=%~2"
    goto :eof

:error
    echo.
    echo [FATAL] %~1
    echo.
    pause
    exit /b 1

:check_tool
    set "tool_name=%~1"
    set "expected_path=%~2"
    set "too_help=%~3"
    if not exist "%expected_path%" (
        echo     %formatted_name%: not found ^(expected: %expected_path%^)
        goto :eof
    )
    for /f "delims=" %%i in ('where %tool_name% 2^>nul') do (
        set "actual_path=%%i"
        goto :found_in_path
    )
    echo     %formatted_name%: exists but not in PATH ^(%expected_path%^)
    goto :eof
    :found_in_path
    if /i "%actual_path%"=="%expected_path%" (
        powershell -NoProfile -Command "Write-Output ('{0,-11} {1,-59} {2,-3} {3}' -f '   %tool_name%','%actual_path%','ok','%too_help%')"
    ) else (
        powershell -NoProfile -Command "Write-Output ('{0,-11} {1,-59} {2}' -f '   %tool_name%','%actual_path%','WARN: expected %expected_path%')"
    )


    goto :eof

:append_env_path
    set "new_path=%~1"
    if not defined PCELF_ENV_PATHS (
        set "PCELF_ENV_PATHS=!new_path!"
    ) else (
        echo ;!PCELF_ENV_PATHS!; | find /I ";!new_path!;" >nul || set "PCELF_ENV_PATHS=!PCELF_ENV_PATHS!;!new_path!"
    )
    echo ;!PATH!; | find /I ";!new_path!;" >nul || set "PATH=!new_path!;!PATH!"
    goto :eof

:fetch_unzip_copy
    set "url=%~1"
    set "download_dir=%~2"
    set "zip_filename=%~3"
    set "extract_dir=%~4"
    set "install_src_dir=%~5"
    set "install_dir=%~6"
    set "cleanup=%~7"
    set "zip_path=!download_dir!\!zip_filename!"
    if not exist "!download_dir!" mkdir "!download_dir!" >nul 2>nul
    if not exist "!zip_path!" (
        echo [INFO] Downloading from: !url!
        powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '!url!' -OutFile '!zip_path!' -ErrorAction Stop } catch { Write-Host '[ERROR] Download failed: ' -NoNewline; Write-Host $_.Exception.Message; exit 1 }"
        if errorlevel 1 goto :error
    )
    powershell -Command "try { Expand-Archive -Path '!zip_path!' -DestinationPath '!extract_dir!' -Force -ErrorAction Stop } catch { Write-Host '[ERROR] Extraction failed: ' -NoNewline; Write-Host $_.Exception.Message; exit 1 }"
    if errorlevel 1 goto :error
    for %%F in ("!install_dir!") do set "parent_dir=%%~dpF"
    if not exist "!parent_dir!" mkdir "!parent_dir!" >nul 2>nul
    if not exist "!install_dir!" mkdir "!install_dir!" >nul 2>nul
    rem Use robocopy for robust copy; treat 0-7 as success
    robocopy "!install_src_dir!" "!install_dir!" /E /NFL /NDL /NJH /NJS /NP >nul
    set "_rc=%errorlevel%"
    if !_rc! GEQ 8 (
        echo [ERROR] Copy failed ^(rc=!_rc!^) from: !install_src_dir! to: !install_dir!
        goto :error
    )
    goto :copy_ok
    :copy_ok
    if /i "!cleanup!"=="yes" (
        if exist "!extract_dir!" rmdir /S /Q "!extract_dir!" >nul 2>nul
        if exist "!zip_path!" del /Q "!zip_path!" >nul 2>nul
    )
    goto :eof
:main





::::: ----------------------------------------------------------------------
::::: Python module: params/install/PATH/check
::::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",python," >nul || goto :skip_python
set "PCELF_PYTHON_HOME=%PCELF_PROJECT_ENV_HOME%\python312"
if not exist "!PCELF_PYTHON_HOME!\python.exe" (
    echo [STEP] Installing Python...
    set "python_download_url=https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip"
    set "python_download_dir=!PCELF_PROJECT_ENV_HOME!\downloads"
    set "python_download_filename=python-3.12.10-embed-amd64.zip"
    set "python_extract_dir=!PCELF_PROJECT_ENV_HOME!\downloads\python-3.12.10-embed-amd64"
    set "python_install_src_dir=!PCELF_PROJECT_ENV_HOME!\downloads\python-3.12.10-embed-amd64"
    set "python_install_dir=!PCELF_PYTHON_HOME!"
    set "python_pth_path=!PCELF_PYTHON_HOME!\python312._pth"
    call :fetch_unzip_copy "!python_download_url!" "!python_download_dir!" "!python_download_filename!" "!python_extract_dir!" "!python_install_src_dir!" "!python_install_dir!" "yes"
    if exist "!python_pth_path!" (
        powershell -NoProfile -Command "(Get-Content '!python_pth_path!') -replace '^\s*#?\s*import site.*$','import site' | Set-Content '!python_pth_path!'" >nul 2>&1
    )
)
rem PATH managed by :append_env_path for %PCELF_PYTHON_HOME%
call :append_env_path "%PCELF_PYTHON_HOME%"
call :check_tool "python" "%PCELF_PYTHON_HOME%\python.exe" "python --version"
    >>"%env_config_example%" echo PCELF_PYTHON_HOME=%PCELF_PYTHON_HOME%
:skip_python





:::: ----------------------------------------------------------------------
:::: Check/install pip if needed
:::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",pip," >nul || goto :skip_pip
rem If Python binary is not present, skip pip handling
if not exist "%PCELF_PYTHON_HOME%\python.exe" (
    echo     pip     : skip ^(python not available^)
    goto :skip_pip
)
set "PCELF_PYTHON_SCRIPTS=%PCELF_PYTHON_HOME%\Scripts"
if not exist "!PCELF_PYTHON_SCRIPTS!\pip.exe" (
    if not exist "!PCELF_PYTHON_HOME!\python.exe" goto :skip_pip
    echo.
    echo [STEP] Installing pip...
    set "pip_download_url=https://bootstrap.pypa.io/get-pip.py"
    set "pip_download_dir=!PCELF_PROJECT_ENV_HOME!\downloads"
    set "pip_download_filename=get-pip.py"
    set "get_pip_path=!pip_download_dir!\!pip_download_filename!"
    if not exist "!pip_download_dir!" mkdir "!pip_download_dir!" >nul 2>nul
    rem cert vars will be handled by auto-fallback on failure
    if not exist "!get_pip_path!" (
        echo [INFO] Downloading get-pip.py from: !pip_download_url!
        powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '!pip_download_url!' -OutFile '!get_pip_path!' -ErrorAction Stop } catch { Write-Host '[ERROR] get-pip.py download failed via IWR: ' -NoNewline; Write-Host $_.Exception.Message; exit 1 }"
        if errorlevel 1 goto :error
 
    )
    "!PCELF_PYTHON_HOME!\python.exe" "!get_pip_path!" >nul 2>&1
    if errorlevel 1 (
        "!PCELF_PYTHON_HOME!\python.exe" "!get_pip_path!" --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org >nul 2>&1
    )
    if errorlevel 1 (
        echo [WARN] pip install failed. Retrying with cleared cert env...
        set "ssl_cert_file_backup=%SSL_CERT_FILE%"
        set "requests_ca_bundle_backup=%REQUESTS_CA_BUNDLE%"
        set "curl_ca_bundle_backup=%CURL_CA_BUNDLE%"
        set "SSL_CERT_FILE="
        set "REQUESTS_CA_BUNDLE="
        set "CURL_CA_BUNDLE="
        "!PCELF_PYTHON_HOME!\python.exe" "!get_pip_path!" >nul 2>&1
        if errorlevel 1 (
            "!PCELF_PYTHON_HOME!\python.exe" "!get_pip_path!" --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org >nul 2>&1
        )
        rem auto-fallback restores backups above if used
        if errorlevel 1 (
            echo [ERROR] pip installation failed after cert fallback.
            goto :error
        )
    )
    if exist "!get_pip_path!" del /Q "!get_pip_path!" >nul 2>nul
)
rem PATH managed by :append_env_path for %PCELF_PYTHON_SCRIPTS%
call :append_env_path "%PCELF_PYTHON_SCRIPTS%"
call :check_tool "pip" "%PCELF_PYTHON_SCRIPTS%\pip.exe" "pip --version"
    >>"%env_config_example%" echo PCELF_PYTHON_SCRIPTS=%PCELF_PYTHON_SCRIPTS%
:skip_pip





:::::: ----------------------------------------------------------------------
:::::: uv module: install/PATH/check
:::::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",uv," >nul || goto :skip_uv
set "PCELF_UV_HOME=%PCELF_PROJECT_ENV_HOME%"
if not exist "!PCELF_UV_HOME!\uv.exe" (
    echo.
    echo [STEP] Installing uv...
    set "uv_download_url=https://github.com/astral-sh/uv/releases/download/0.7.12/uv-x86_64-pc-windows-msvc.zip"
    set "uv_download_dir=!PCELF_PROJECT_ENV_HOME!\downloads"
    set "uv_download_filename=uv-x86_64-pc-windows-msvc.zip"
    set "uv_extract_dir=!uv_download_dir!\uv-x86_64-pc-windows-msvc"
    set "uv_install_src_dir=!uv_extract_dir!"
    set "uv_install_dir=!PCELF_UV_HOME!"
    call :fetch_unzip_copy "!uv_download_url!" "!uv_download_dir!" "!uv_download_filename!" "!uv_extract_dir!" "!uv_install_src_dir!" "!uv_install_dir!" "yes"
)
rem PATH managed by :append_env_path for %PCELF_UV_HOME%
call :append_env_path "%PCELF_UV_HOME%"
call :check_tool "uv" "%PCELF_UV_HOME%\uv.exe" "uv --version"
    >>"%env_config_example%" echo PCELF_UV_HOME=%PCELF_UV_HOME%
:skip_uv





:::::: ----------------------------------------------------------------------
:::::: bun module: install/PATH/check
:::::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",bun," >nul || goto :skip_bun
set "PCELF_BUN_HOME=%PCELF_PROJECT_ENV_HOME%"
if not exist "!PCELF_BUN_HOME!\bun.exe" (
    echo.
    echo [STEP] Installing Bun...
    set "bun_download_url=https://github.com/oven-sh/bun/releases/download/bun-v1.2.15/bun-windows-x64.zip"
    set "bun_download_dir=!PCELF_PROJECT_ENV_HOME!\downloads"
    set "bun_download_filename=bun-windows-x64.zip"
    set "bun_extract_dir=!bun_download_dir!\bun-windows-x64"
    set "bun_install_src_dir=!bun_extract_dir!\bun-windows-x64"
    set "bun_install_dir=!PCELF_BUN_HOME!"
    call :fetch_unzip_copy "!bun_download_url!" "!bun_download_dir!" "!bun_download_filename!" "!bun_extract_dir!" "!bun_install_src_dir!" "!bun_install_dir!" "yes"
    >"!bun_install_dir!\bunx.cmd" echo @echo off
    >>"!bun_install_dir!\bunx.cmd" echo "%%~dp0bun.exe" x %%*
)
rem PATH managed by :append_env_path for %PCELF_BUN_HOME%
call :append_env_path "%PCELF_BUN_HOME%"
call :check_tool "bun" "%PCELF_BUN_HOME%\bun.exe" "bun --version"
    >>"%env_config_example%" echo PCELF_BUN_HOME=%PCELF_BUN_HOME%
:skip_bun





:::::: ----------------------------------------------------------------------
:::::: pwsh module: install/PATH/check
:::::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",pwsh," >nul || goto :skip_pwsh
set "PCELF_PWSH_HOME=%PCELF_PROJECT_ENV_HOME%\pwsh"
if not exist "!PCELF_PWSH_HOME!\pwsh.exe" (
    echo.
    echo [STEP] Installing PowerShell 7...
    set "pwsh_download_url=https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.zip"
    set "pwsh_download_dir=!PCELF_PROJECT_ENV_HOME!\downloads"
    set "pwsh_download_filename=PowerShell-7.5.2-win-x64.zip"
    set "pwsh_extract_dir=!pwsh_download_dir!\PowerShell-7.5.2-win-x64"
    set "pwsh_install_src_dir=!pwsh_extract_dir!"
    set "pwsh_install_dir=!PCELF_PWSH_HOME!"
    call :fetch_unzip_copy "!pwsh_download_url!" "!pwsh_download_dir!" "!pwsh_download_filename!" "!pwsh_extract_dir!" "!pwsh_install_src_dir!" "!pwsh_install_dir!" "yes"
)
rem PATH managed by :append_env_path for %PCELF_PWSH_HOME%
call :append_env_path "%PCELF_PWSH_HOME%"
call :check_tool "pwsh" "%PCELF_PWSH_HOME%\pwsh.exe" "pwsh --version / $PSVersionTable"
    >>"%env_config_example%" echo PCELF_PWSH_HOME=%PCELF_PWSH_HOME%
:skip_pwsh





:::::: ----------------------------------------------------------------------
:::::: pm2 module: install/check via bun
:::::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",pm2," >nul || goto :skip_pm2
rem If bun is not available, skip pm2 handling
where bun >nul 2>nul || (
    echo     pm2     : skip ^(bun not available^)
    goto :skip_pm2
)
set "PCELF_PM2_HOME=%PCELF_PROJECT_ENV_HOME%\node_modules\.bin"
set "PM2_HOME=%PCELF_PROJECT_ENV_HOME%\data_pm2"
if not exist "%PCELF_PM2_HOME%\pm2.exe" (
    echo.
    echo [STEP] Installing pm2 via bun...
    pushd "!PCELF_PROJECT_ENV_HOME!"
    bun install pm2 >nul 2>&1
    if not "!errorlevel!"=="0" echo [WARN] pm2 installation failed via bun install ^(skipping pm2^)
    popd
)
rem PATH managed by :append_env_path for %PCELF_PM2_HOME%
call :append_env_path "%PCELF_PM2_HOME%"
call :check_tool "pm2" "%PCELF_PM2_HOME%\pm2.exe" "pm2 --version"
    >>"%env_config_example%" echo PCELF_PM2_HOME=%PCELF_PM2_HOME%
    >>"%env_config_example%" echo PM2_HOME=%PM2_HOME%
:skip_pm2








    >>"%env_config_example%" echo PCELF_ENV_PATHS=%PCELF_ENV_PATHS%
    >>"%env_config_example%" echo ######## 你的自定义环境变量 Your Custom Environment Variables:
    >>"%env_config_example%" echo %env_managed_end%
:: ----------------------------------------------------------------------
:: vscode module: auto-maintain .vscode/settings.json
:: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",vscode," >nul || goto :skip_vscode
set "VSCODE_DIR=%PCELF_PROJECT_HOME%\.vscode"
set "VSCODE_SETTINGS=%VSCODE_DIR%\settings.json"
if not exist "%VSCODE_DIR%" mkdir "%VSCODE_DIR%" >nul 2>nul
set "_PY_EXE=%PCELF_PYTHON_HOME%\python.exe"
set "_PW_EXE=%PCELF_PWSH_HOME%\pwsh.exe"
set "_PY_EXE_N=%_PY_EXE:\=/%"
set "_PW_EXE_N=%_PW_EXE:\=/%"
set "i=!"
>"%VSCODE_SETTINGS%"  echo //%i%%i%%i% 内容自动生成, 请在%~nx0 修订, 否者将会被覆盖 %i%%i%%i%
>>"%VSCODE_SETTINGS%" echo //%i%%i%%i% Content is auto generated, Revise it in %~nx0 or it will be overwritten %i%%i%%i%
>>"%VSCODE_SETTINGS%" echo {
>>"%VSCODE_SETTINGS%" echo   "python.defaultInterpreterPath": "%_PY_EXE_N%",
>>"%VSCODE_SETTINGS%" echo   "python.terminal.activateEnvironment": true,
>>"%VSCODE_SETTINGS%" echo. 
>>"%VSCODE_SETTINGS%" echo   "terminal.integrated.defaultProfile.windows": "pwsh",
>>"%VSCODE_SETTINGS%" echo   "terminal.integrated.profiles.windows": {
>>"%VSCODE_SETTINGS%" echo     "pwsh": {
>>"%VSCODE_SETTINGS%" echo       "path": "%_PW_EXE_N%",
>>"%VSCODE_SETTINGS%" echo       "args": [],
>>"%VSCODE_SETTINGS%" echo       "overrideName": true
>>"%VSCODE_SETTINGS%" echo     }
>>"%VSCODE_SETTINGS%" echo   }
>>"%VSCODE_SETTINGS%" echo }
:skip_vscode





:::::: ----------------------------------------------------------------------
:::::: envsync module: sync env.example managed region into .env
:::::: ----------------------------------------------------------------------
echo ,%modules_enable%, | find /I ",envsync," >nul || goto :skip_envsync
if not exist "%env_config_example%" goto :skip_envsync
rem If .env doesn't exist, copy env.example to .env
if not exist "%env_config%" (
    echo [INFO] Creating .env from env.example
    copy /Y "%env_config_example%" "%env_config%" >nul
    goto :skip_envsync
)
rem Check if .env has BEGIN marker
findstr /C:"%env_managed_begin%" "%env_config%" >nul 2>&1
if errorlevel 1 (
    echo [WARN] %env_managed_begin% not found in .env, skipping sync
    echo       To enable sync, add the managed section markers to .env or delete .env to recreate it
    goto :skip_envsync
)

rem Check if .env has END marker
findstr /C:"%env_managed_end%" "%env_config%" >nul 2>&1
if errorlevel 1 (
    echo [WARN] %env_managed_end% not found in .env, skipping sync
    echo       The managed section is incomplete. Please fix the markers in .env
    goto :skip_envsync
)
rem Both markers exist, use PowerShell to handle encoding and preserve empty lines
powershell -NoProfile -Command ^
"$env = '%env_config%'; $ex = '%env_config_example%'; $begin = '%env_managed_begin%'; $end = '%env_managed_end%'; ^
try { ^
    $content = [System.IO.File]::ReadAllText($env, [System.Text.Encoding]::UTF8); ^
    $beginIdx = $content.IndexOf($begin); ^
    $endIdx = $content.IndexOf($end); ^
    if ($beginIdx -ge 0 -and $endIdx -gt $beginIdx) { ^
        $endLineIdx = $content.IndexOf([Environment]::NewLine, $endIdx) + [Environment]::NewLine.Length; ^
        if ($endLineIdx -le [Environment]::NewLine.Length) { $endLineIdx = $content.Length }; ^
        $pre = $content.Substring(0, $beginIdx); ^
        $post = $content.Substring($endLineIdx); ^
        $managed = [System.IO.File]::ReadAllText($ex, [System.Text.Encoding]::UTF8); ^
        $new = $pre + $managed + $post; ^
        [System.IO.File]::WriteAllText($env, $new, [System.Text.UTF8Encoding]::new($false)); ^
        Write-Output ('{0,-11} {1,-59} {2,-3} {3}' -f '  .env sync','%env_config_example%','ok','https://%PCELF_PROJECT_NAME%'); ^
    } else { ^
        Write-Host 'Error: Could not locate managed section boundaries'; ^
    } ^
} catch { ^
    Write-Host ('Error: ' + $_.Exception.Message); ^
}"
:skip_envsync





::::: ----------------------------------------------------------------------
::::: Load .env to override defaults (same style as activate.cmd)
::::: ----------------------------------------------------------------------
if exist "%env_config%" (
    for /f "usebackq tokens=1* delims==" %%A in ("%env_config%") do (
        if not "%%A"=="" if not "%%A:~0,1"=="#" (
            call :set_var "%%A" %%B
        )
    )
) else (
    echo.
    echo [INFO] .env not found: %env_config%
)





echo.
cmd /c "%PCELF_FINAL_CMD%"





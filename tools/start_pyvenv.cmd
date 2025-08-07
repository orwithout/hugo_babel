@echo off
chcp 65001 >nul

setlocal enabledelayedexpansion

rem ------------------------------------------------------------------------------
rem 【一】环境变量定义
rem ------------------------------------------------------------------------------

rem 获取脚本所在目录 (末尾带反斜杠)
set "SCRIPT_DIR=%~dp0"
rem 虚拟环境目录
set "ENV_PATH=%SCRIPT_DIR%.venv"
rem 依赖已安装标记文件
set "FLAG_FILE=%ENV_PATH%\deps_installed.txt"
rem requirements.txt 文件路径
set "REQ_FILE=%SCRIPT_DIR%requirements.txt"

rem ------------------------------------------------------------------------------
rem 【二】检测 / 创建 / 修复虚拟环境
rem ------------------------------------------------------------------------------

if not exist "%ENV_PATH%" (
    echo [INFO] 未检测到虚拟环境, 正在创建...
    python -m venv "%ENV_PATH%"
) else (
    rem 如果已经存在虚拟环境, 先试着激活, 如果失败就重建
    call "%ENV_PATH%\Scripts\activate.bat" 2>nul
    if not "%errorlevel%"=="0" (
        echo [WARN] 虚拟环境激活失败, 可能是由于路径变化导致, 正在重新创建...
        rem 先尝试删除原环境
        call :_safe_deactivate
        rmdir /s /q "%ENV_PATH%" 2>nul
        python -m venv "%ENV_PATH%"
    ) else (
        rem 已激活, 则再检查一下 Python 是否可用
        python --version >nul 2>nul
        if errorlevel 1 (
            echo [WARN] 虚拟环境无法正常使用, 正在重新创建...
            call :_safe_deactivate
            rmdir /s /q "%ENV_PATH%" 2>nul
            python -m venv "%ENV_PATH%"
        ) else (
            rem 虚拟环境有效
            call :_safe_deactivate
        )
    )
)

rem 再次激活新创建或修复后的虚拟环境
call "%ENV_PATH%\Scripts\activate.bat"

rem ------------------------------------------------------------------------------
rem 【三】根据标记文件与 requirements.txt 状态做判断
rem ------------------------------------------------------------------------------

rem 如果已经安装依赖, 则跳转到 Shell
if exist "%FLAG_FILE%" (
    goto shell
)

rem 如果没有安装依赖, 则进入菜单
:main_menu
cls
echo ==========================
echo         主菜单
echo ==========================
echo.
echo 1. 安装 requirements.txt
echo 2. 生成 requirements.txt
echo 3. 进入 Shell
echo.
choice /C 123 /N /M "请选择一个选项: "
if errorlevel 3 goto shell
if errorlevel 2 goto generate_req
if errorlevel 1 goto install_req

rem ------------------------------------------------------------------------------
rem 【四】执行菜单选项逻辑
rem ------------------------------------------------------------------------------

:install_req
if not exist "%REQ_FILE%" (
    echo [ERROR] 未找到 requirements.txt 文件, 无法安装依赖。
    echo [HINT] 请先生成 requirements.txt 文件。
    echo [INFO] 按任意键返回主菜单...
    pause >nul
    goto main_menu
)
echo [INFO] 正在安装 %REQ_FILE% 中的依赖...
pip install -r "%REQ_FILE%"
if errorlevel 1 (
    echo [ERROR] 安装依赖失败, 请检查 pip 或网络问题。
    echo [INFO] 按任意键返回主菜单...
    pause >nul
    goto main_menu
)

echo Installed> "%FLAG_FILE%"
echo [INFO] 依赖安装完成, 按任意键返回主菜单...
pause >nul
goto main_menu

:generate_req
echo [INFO] 正在生成 requirements.txt 文件...
pip freeze > "%REQ_FILE%"
echo [INFO] requirements.txt 文件已生成, 按任意键返回主菜单...
pause >nul
goto main_menu

:shell
echo [INFO] 进入虚拟环境 Shell...
cmd /k
goto :eof

rem ------------------------------------------------------------------------------
rem 【五】辅助函数: 安全地 deactivate
rem ------------------------------------------------------------------------------
:_safe_deactivate
    rem 如果当前 shell 已激活虚拟环境, 则可以尝试执行 deactivate 命令
    rem (有些情况下 deactivate 脚本可能找不到, 静默处理错误即可)
    deactivate 2>nul
    goto :eof

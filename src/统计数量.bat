batch
@echo off
setlocal enabledelayedexpansion
set "output_file=files_folders_list.txt"

echo 正在统计当前文件夹及其子文件夹中的所有文件，并将结果保存到 %output_file%

if exist "%output_file%" del "%output_file%"

for /r %%i in (*) do (
echo %%~nxi >> "%output_file%"
)

for /d /r %%i in (*) do (
echo %%~nxi >> "%output_file%"
)

echo 所有文件和文件夹的名称已保存到 %output_file%
endlocal
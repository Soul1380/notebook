@echo off
set "NOTEBOOK_NODE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
if not exist "%NOTEBOOK_NODE%" set "NOTEBOOK_NODE=node"
start "" /min "%NOTEBOOK_NODE%" "%~dp0desktop.cjs"

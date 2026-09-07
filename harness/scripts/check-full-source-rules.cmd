@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-full-source-rules.ps1" %*

@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-localization-rules.ps1" %*

@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-compose-rules.ps1" %*

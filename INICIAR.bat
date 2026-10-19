@echo off
chcp 65001 >nul
cd /d "%~dp0"
title GearX - simulador do Lupi
where python >nul 2>nul
if errorlevel 1 (
  echo Python nao encontrado. Instale em https://www.python.org/downloads/ e marque "Add python.exe to PATH".
  pause
  exit /b 1
)
python ferramentas\servidor.py
if errorlevel 1 pause

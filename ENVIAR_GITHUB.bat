@echo off
chcp 65001 >nul
cd /d "%~dp0"
title GearX - enviar para o GitHub
where git >nul 2>nul
if errorlevel 1 (
  echo Git nao encontrado. Instale em https://git-scm.com/download/win
  pause
  exit /b 1
)
echo Construindo o jogo...
python ferramentas\construir.py
if errorlevel 1 (
  echo.
  echo O jogo tem erros. Corrija antes de enviar.
  pause
  exit /b 1
)
echo.
git add -A
git commit -q -m "Versao de %date% %time:~0,5%"
if errorlevel 1 echo Nada de novo para guardar.
echo Enviando para o GitHub...
git push
if errorlevel 1 (
  echo.
  echo Nao consegui enviar. Veja a mensagem acima.
) else (
  echo.
  echo Pronto! Versao enviada.
)
pause

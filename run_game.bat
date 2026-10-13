@echo off
rem Play the game (pass extra options after the script name, e.g. run_game.bat --autoplay)
"D:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --path "%~dp0." -- %*

# Monitor Local Alt-Tab

An AutoHotkey script that makes Alt-Tab work separately on each monitor.

## How It Works

The script detects which monitor the mouse is currently on and limits Alt-Tab to the windows displayed on that monitor.

For example, if VS Code, Command Prompt, and File Explorer are open on a second monitor while a browser is open on the laptop display, Alt-Tab on the second monitor will only switch between VS Code, Command Prompt, and File Explorer.

Moving the mouse to the laptop display will make Alt-Tab switch between the windows on that display instead.

## Requirements

Windows and AutoHotkey v2.

## Usage

Run the script and use Alt-Tab normally. The monitor containing the mouse determines which windows are included in the Alt-Tab switcher.

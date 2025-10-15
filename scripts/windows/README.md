# Windows single-file EXE (SFX)

This folder contains scripts to package the Flutter Windows app into a single self-extracting EXE (SFX). When users run the EXE, it extracts to a temp folder and launches the app immediately.

Why SFX? Flutter for Windows requires multiple DLLs and assets next to the executable, so a true single binary is not supported. The SFX approach provides a practical one-file distribution.

## Prerequisites (on the build machine)

- Windows 10/11
- Visual Studio with "Desktop development with C++"
- Flutter SDK (Windows desktop enabled)
- 7-Zip (for 7z and 7zS.sfx)

## Output

- apps/flutter_demo/releases/MerkleKV-Mobile.exe (default)

## Usage

PowerShell:

```
# From repo root
./scripts/windows/make-sfx.ps1

# Custom output and custom SFX stub
./scripts/windows/make-sfx.ps1 -Output C:\dist\MerkleKV-Mobile.exe -SevenZipSfx "C:\\Program Files\\7-Zip\\7zS.sfx"
```

CMD:

```
REM From repo root
scripts\windows\make-sfx.cmd

REM Custom output and SFX stub
scripts\windows\make-sfx.cmd C:\dist\MerkleKV-Mobile.exe "C:\\Program Files\\7-Zip\\7zS.sfx"
```

## What the script does

1. Builds the Flutter Windows app in `apps/flutter_demo`
2. Finds the Release output in `build/windows/x64/runner/Release`
3. Creates a 7z archive of the Release folder
4. Generates an SFX config to auto-run `flutter_demo.exe`
5. Concatenates `7zS.sfx + config.txt + payload.7z` into a single EXE

## Notes

- Code signing is recommended to avoid SmartScreen warnings.
- If your CPU arch differs (e.g., arm64), adjust the Release path in the script.
- To change the window title and file properties, edit `apps/flutter_demo/windows/runner/Runner.rc` and CMake settings (`BINARY_NAME`).

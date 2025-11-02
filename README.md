# MotW Unblocker

A Windows utility for viewing, adding, or removing **Mark-of-the-Web (MotW)** metadata on files.

## Overview

When a file is downloaded from the internet, Windows adds a `Zone.Identifier` alternate data stream to mark it as “untrusted.”
This can disable previews and trigger security warnings when opening the file.

**MotW Unblocker** provides a graphical interface to safely inspect and manage this metadata for trusted files.

---

## Installation

### Pre-built Binaries

After building or publishing the project, you’ll find the compiled executables in your local build output directories:

- **[bin\Release\SelfContained\](bin/Release/SelfContained/)** — contains `MotWUnblocker-sc.exe`
- **[bin\Release\FddSingle\](bin/Release/FddSingle/)** — contains `MotWUnblocker-fdd.exe`

Download the desired `.exe` from either directory, depending on your preferred build flavor.

| Build Type              | Output Directory             | Description                                                            |
| ----------------------- | ---------------------------- | ---------------------------------------------------------------------- |
| **Self-Contained**      | `bin\Release\SelfContained\` | Includes the .NET runtime — runs on any Windows 10/11 x64 system.      |
| **Framework-Dependent** | `bin\Release\FddSingle\`     | Smaller binary that uses the installed .NET 9 Windows Desktop Runtime. |

### System Requirements

| Requirement | Self-Contained                       | Framework-Dependent                         |
| ----------- | ------------------------------------ | ------------------------------------------- |
| OS          | Windows 10 (21H2+) or Windows 11 x64 | Windows 10 (21H2+) or Windows 11 x64        |
| Runtime     | Bundled                              | Requires `Microsoft.WindowsDesktop.App 9.x` |

---

## Usage

### Adding Files
- Click **“Add Files…”** to browse and select files, or
- Drag-and-drop files directly into the window.

### Managing MotW
1. Select one or more files using the checkboxes.
2. Click **Unblock Selected** to remove the `Zone.Identifier` stream.
3. Click **Block (Add MotW)** to restore it.
4. Click **Refresh Status** to rescan file metadata.

### Features
- Batch processing
- Real-time status indicators
- Drag-and-drop support
- Detailed local logging
- No elevated permissions required

### Logging
Logs are stored at:
`%LOCALAPPDATA%\MotWUnblocker\unblocker.log`

Use the **“Open Log Folder”** button inside the app to view logs.

---

## Developer Information

### Building From Source

#### Restore Dependencies
Before the first build:
```powershell
dotnet restore
```
This downloads any required NuGet packages and generates the project assets file.

#### Build a Single Flavor
```powershell
# Full, self-contained EXE
dotnet publish -c Release -p:PublishFlavor=SelfContained
# → bin\Release\SelfContained\MotWUnblocker-sc.exe

# Small, framework-dependent EXE (uses installed .NET runtime)
dotnet publish -c Release -p:PublishFlavor=FddSingle
# → bin\Release\FddSingle\MotWUnblocker-fdd.exe
```

Each `dotnet publish` automatically performs a restore if needed.

#### Build Both Flavors Together
If you prefer one command for both:
```powershell
dotnet msbuild -t:PublishBoth -p:Configuration=Release
# → bin\Release\SelfContained\MotWUnblocker-sc.exe
# → bin\Release\FddSingle\MotWUnblocker-fdd.exe
```

> **Note:** `dotnet msbuild` does *not* restore automatically, so the `-restore` flag (or a separate `dotnet restore`) is required.

---

### Project Structure
```
Models/           Data models and view models
Services/         Core logic for MotW read/write
Utils/            Logging and helper functions
MainWindow.xaml   WPF user interface
```

### Technical Specifications
- **Framework:** .NET 9.0
- **UI:** Windows Presentation Foundation (WPF)
- **Deployment:** Dual-flavor (Self-Contained + Framework-Dependent)
- **Target Platform:** Windows x64
- **Binary Size:**
  - Self-Contained ≈ 60 MB
  - Framework-Dependent ≈ 176 KB

### Build Configuration Summary
- `PublishTrimmed = false` (WPF-safe)
- `PublishSingleFile = true` for both flavors
- `SelfContained` toggled per flavor
- Optional compression enabled for single-file mode
- Custom MSBuild target **PublishBoth** builds both flavors sequentially
- Each flavor publishes into its own folder (`bin\Release\SelfContained\` and `bin\Release\FddSingle\`)

---

## Security Considerations

This utility modifies NTFS **alternate data streams** only.
File content and hashes remain unchanged.
Use on trusted files only — removing MotW should never be used to bypass corporate or system security controls.

---

## License

**MIT License** — see the [LICENSE](LICENSE) file for details.

---

## Support

For issues, feature requests, or build questions, please open an issue on the project’s GitHub **Issues** page.

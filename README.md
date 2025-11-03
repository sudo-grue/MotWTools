# MotW Tools

A suite of Windows utilities for viewing, adding, or removing **Mark-of-the-Web (MotW)** metadata from files.

## Executive Summary

Microsoft’s recent security updates (notably Windows 11 25H2 / KB5070960) expanded enforcement of the Mark-of-the-Web feature, preventing the preview of downloaded files and adding additional safety prompts.
While this change improves protection against credential leaks and malicious file execution, it also creates real productivity friction for trusted internal documents.

**MotW Tools** provides a safe, auditable way to manage this metadata for files originating from trusted sources.
The suite includes:

| Component          | Type                  | Description                                                                                  |
| ------------------ | --------------------- | -------------------------------------------------------------------------------------------- |
| **MotW Unblocker** | GUI Application (WPF) | Provides a graphical interface for batch inspection and removal of MotW metadata.            |
| **MotW.ps1**       | PowerShell Script     | Lightweight command-line and “Send To” integration for quick unblocking without UI overhead. |

Both tools operate per-user and require no administrative rights.

---

## Overview

When Windows detects a file downloaded from the Internet, it appends a small hidden stream named `Zone.Identifier` that flags the file as **Zone 3 (Internet)**.
This metadata:
- Disables file previews in Explorer and Outlook
- Triggers additional warning prompts
- Blocks some scripts or macros from running

MotW Tools modifies only this metadata; the original file contents and hashes remain unchanged.

---

## GUI Application: MotW Unblocker

### Installation

After building or publishing the project, you’ll find the compiled executables in your local build output directories:

- [MotWUnblocker-sc.exe (Self-Contained; ≈60 MB)](MotWUnblocker/bin/Release/SelfContained/MotWUnblocker-sc.exe)
- [MotWUnblocker-fdd.exe (Framework-Dependent; ≈177 KB)](MotWUnblocker/bin/Release/FddSingle/MotWUnblocker-fdd.exe)

| Build Type              | Output Directory             | Description                                                                 |
| ----------------------- | ---------------------------- | --------------------------------------------------------------------------- |
| **Self-Contained**      | `bin\Release\SelfContained\` | Includes the .NET runtime — runs on any Windows 10/11 x64 system.           |
| **Framework-Dependent** | `bin\Release\FddSingle\`     | Smaller binary that requires the installed `.NET 9 WindowsDesktop` runtime. |

### System Requirements

| Requirement | Self-Contained                       | Framework-Dependent                  |
| ----------- | ------------------------------------ | ------------------------------------ |
| OS          | Windows 10 (21H2+) or Windows 11 x64 | Windows 10 (21H2+) or Windows 11 x64 |
| Runtime     | Bundled                              | `Microsoft.WindowsDesktop.App 9.x`   |

### Usage

- Click **Add Files…** or drag-and-drop files into the window.
- Use checkboxes to select files, then:
  - **Unblock Selected** → remove `Zone.Identifier`
  - **Block (Add MotW)** → add MotW metadata
  - **Refresh Status** → update displayed state

**Features**
- Batch processing
- Real-time status indicators
- Drag-and-drop support
- Detailed local logging
- No elevated permissions required

**Logs:**
`%LOCALAPPDATA%\MotWUnblocker\unblocker.log`
Accessible via the **Open Log Folder** button.

---

## PowerShell CLI Tools

The `scripts/` directory contains automation-friendly tools that can be installed per-user without admin rights.

### Scripts Included
| Script                        | Purpose                                                          |
| ----------------------------- | ---------------------------------------------------------------- |
| **MotW.ps1**                  | Core logic for adding/removing/status checking of MotW metadata. |
| **Install-MotWContext.ps1**   | Installs the CLI tool and “Send To → MotW – Unblock” shortcut.   |
| **Uninstall-MotWContext.ps1** | Cleanly removes all installed components.                        |

---

### Quick Installation

```powershell
# Run from the scripts directory
.\Install-MotWContext.ps1
```

**Installs:**
- `%USERPROFILE%\Tools\MotW\MotW.ps1`
- Adds `%USERPROFILE%\Tools\MotW` to the user PATH
- Creates **Send To → MotW – Unblock** command (no registry edits)

To remove everything later:
```powershell
.\Uninstall-MotWContext.ps1 -RemoveFiles
```

---

### Manual Installation (Advanced)

If you prefer not to run the installer:

1. Create a folder:
   `C:\Users\<User>\Tools\MotW`
2. Copy `MotW.ps1` into that folder.
3. Add the folder to your **User PATH**:
   _Settings → System → About → Advanced System Settings → Environment Variables → User variables → Path._
4. Optional: add a `.cmd` to `shell:sendto` containing
   ```bat
   @echo off
   powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\Tools\MotW\MotW.ps1" unblock "%~1"
   ```

---

### CLI Usage

```powershell
MotW.ps1 *.pdf
MotW.ps1 unblock *.docx
MotW.ps1 add *.exe
MotW.ps1 status .
MotW.ps1 unblock . -Recurse
```

**Actions**
| Action    | Description                                   |
| --------- | --------------------------------------------- |
| `unblock` | Removes MotW metadata (default).              |
| `add`     | Adds MotW metadata (`ZoneId=3`).              |
| `status`  | Displays `[MotW]` or `[clean]` for each file. |

**Examples**
```powershell
# Unblock all PDFs in current folder
MotW.ps1 *.pdf

# Check status of all files recursively
MotW.ps1 status . -Recurse

# Add MotW metadata back to executables
MotW.ps1 add *.exe
```

---

### Scheduled or Automated Usage

For routine compliance or maintenance, the CLI can be run as a **Scheduled Task** without user interaction:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File "C:\Users\<User>\Tools\MotW\MotW.ps1" unblock "C:\TrustedFiles\*.pdf"
```

Common scenarios:
- Clear MotW from a trusted download folder each night.
- Audit MotW status weekly across a shared directory (`status . -Recurse`).
- Reapply MotW to outbound transfer folders before uploads.

Tasks should run as the logged-in user (not SYSTEM) to ensure the same access context.

---

## Developer Information

### Building From Source

```powershell
cd .\MotWUnblocker\
```

To build individual binary:
```powershell
dotnet restore
dotnet publish -c Release -p:PublishFlavor=SelfContained
dotnet publish -c Release -p:PublishFlavor=FddSingle
```

To build both:
```powershell
dotnet msbuild -t:PublishBoth -p:Configuration=Release
```

---

### Project Structure
```
MotWUnblocker/
├── Models/           # Data models and view models
├── Services/         # MotW read/write logic
├── Utils/            # Logging helpers
└── MainWindow.xaml   # WPF UI definition
scripts/
├── MotW.ps1
├── Install-MotWContext.ps1
└── Uninstall-MotWContext.ps1
```

---

### Technical Specifications
- **Framework:** .NET 9.0
- **UI:** WPF (Windows Presentation Foundation)
- **Deployment:** Dual-flavor (Self-Contained + Framework-Dependent)
- **Target:** Windows x64
- **Binary Sizes:** Self-Contained ≈ 60 MB · Framework-Dependent ≈ 177 KB
- **PowerShell Version:** 5.1 or higher
- **Permissions:** Per-user only (no admin rights required)

---

## Security Considerations

These tools modify only **NTFS alternate data streams** (`Zone.Identifier`).
They never alter file content or integrity.
Usage should remain limited to trusted environments where restoring preview functionality or removing redundant security prompts does not weaken required security policy.

---

## Support and Contact

For questions, feature requests, or deployment guidance, open an issue on the project’s **GitHub Issues** page.

# MotW Unblocker

A Windows utility for removing Mark-of-the-Web (MotW) metadata from files.

## Overview

When files are downloaded from the internet, Windows automatically adds a Zone.Identifier alternate data stream to mark them as originating from an untrusted source. This causes security warnings when opening files. MotW Unblocker provides a graphical interface to manage these marks on trusted files.

## Installation

### Pre-built Binary

Download the latest release from the releases section. The application is distributed as a self-contained executable requiring no installation.

1. Download `MotWUnblocker.exe`
2. Copy to desired location
3. Run the application

### System Requirements

- Windows 10 or later (x64)
- No additional dependencies required

## Usage

### Adding Files

Files can be added to the application using either method:
- Click "Add Files..." to browse and select files
- Drag and drop files directly into the application window

### Managing Mark-of-the-Web

1. Select files using the checkbox column
2. Click "Unblock Selected" to remove MotW metadata
3. Click "Block (Add MotW)" to add MotW metadata
4. Click "Refresh Status" to update the current MotW state

### Features

- Batch processing support
- Real-time status indicators
- Drag and drop interface
- Comprehensive activity logging

### Logging

Application logs are stored in: `%LOCALAPPDATA%\MotWUnblocker\unblocker.log`

Use the "Open Log Folder" button to access logs directly from the application.

## Developer Information

### Building from Source

Build the application using the .NET SDK:

```bash
dotnet publish -c Release
```

Output location:
```
bin\Release\net9.0-windows\win-x64\publish\MotWUnblocker.exe
```

### Project Structure

```
Models/           Data models and view models
Services/         Core business logic
Utils/            Logging and utility functions
MainWindow.xaml   User interface definition
```

### Technical Specifications

- **Framework**: .NET 9.0
- **UI Framework**: Windows Presentation Foundation (WPF)
- **Deployment**: Self-contained single-file executable
- **Binary Size**: ~64 MB (includes .NET runtime)
- **Target Platform**: Windows x64

### Build Configuration

The project is configured for standalone deployment:

- Self-contained runtime (no .NET installation required)
- Single-file publishing with compression
- Ready-to-run compilation for improved startup performance
- NTFS alternate data stream manipulation

### Security Considerations

This utility modifies NTFS alternate data streams (Zone.Identifier) without altering file content. Exercise caution and only process files from trusted sources.

## License

MIT License - See LICENSE file for details.

## Support

For issues or feature requests, please use the GitHub issue tracker.

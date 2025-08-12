# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application called "test_open_rdp" that serves as an RDP (Remote Desktop Protocol) connection manager for macOS. The app creates RDP files and launches connections using the macOS "Windows App" application, while tracking and managing active connections.

## Key Commands

### Development
- `flutter run` - Run the app in development mode
- `flutter run -d macos` - Run specifically on macOS
- `flutter run -d chrome` - Run in web browser
- `flutter build macos` - Build for macOS release
- `flutter build web` - Build for web

### Testing and Analysis
- `flutter test` - Run all tests
- `flutter analyze` - Run static analysis (uses analysis_options.yaml)
- `dart fix --apply` - Apply automated fixes for lint issues

### Dependencies
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Update dependencies
- `flutter pub outdated` - Check for outdated packages

### Platform-specific
- `flutter clean` - Clean build artifacts
- `flutter doctor` - Check Flutter environment setup

## Architecture

### Main Application Structure
- **lib/main.dart** - Single-file application containing:
  - `RDPApp`: Root MaterialApp widget
  - `RDPConnectionPage`: Main UI page for managing connections
  - `RDPConnection`: Data model for connection tracking

### Core Functionality
The app operates through these main processes:

1. **RDP File Creation** (`_createRdpFile`): Generates .rdp files with connection parameters in the system temp directory
2. **Connection Launch** (`_connectRDP`): Uses macOS `open -a "Windows App"` command to launch RDP files
3. **Process Management**: Tracks Windows App PIDs using `pgrep` and `ps` commands
4. **Connection Monitoring**: Auto-refresh functionality to monitor connection status every 30 seconds

### Key Dependencies
- `path_provider: ^2.1.5` - For accessing system directories
- `path: ^1.9.1` - For path manipulation
- `cupertino_icons: ^1.0.8` - iOS-style icons
- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules

### Platform Support
- **Primary**: macOS (uses macOS-specific Windows App)
- **Secondary**: Web, iOS, Android, Linux, Windows (Flutter multi-platform)
- **Dependencies**: Requires "Windows App" to be installed on macOS for RDP functionality

### Security Considerations
- Passwords are stored in plain text in RDP files (noted as needing improvement in comments)
- RDP files are automatically deleted 1 minute after connection
- Files are created in system temporary directory

### State Management
Uses built-in Flutter StatefulWidget with setState() for:
- Form validation and input handling
- Connection status tracking
- Active connections list management
- Auto-refresh timer management

## Testing
The test file (test/widget_test.dart) contains outdated tests referencing a non-existent `MyApp` widget. Tests need to be updated to work with the actual `RDPApp` structure.
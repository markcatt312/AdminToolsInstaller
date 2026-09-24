# AdminToolsInstaller - Requirements and Architecture

## Overview
The AdminToolsInstaller project is designed to manage the installation and removal of Remote Server Administration Tools (RSAT) and Windows Optional Features (such as Hyper-V Management Tools) on Windows 11 devices. The primary deployment mechanism for this solution is Microsoft Intune.

## Requirements

### Functional Requirements
1. **Tool Management:** The script must support the Installation, Removal, or Ignoring of Windows RSAT capabilities and Windows Optional Features.
2. **Configuration-Driven:** The toolsets and roles must be defined in a configuration file (JSON) to allow easy updates without modifying the core PowerShell script.
3. **Role-Based Installation:** The script must support installing a predefined set of tools based on a selected "Role" (e.g., `SOE`, `All`).
4. **Standalone Execution:** The core functionality must work via direct PowerShell invocation as well as through Intune.

### Deployment Requirements (Intune Win32 App)
1. **Intune Compatibility:** The script must be capable of being deployed as a Win32 App via Microsoft Intune, running in a 64-bit PowerShell context as the `SYSTEM` account.
2. **Detection Method:** A robust detection method is required for Intune to determine if the desired toolset has been successfully installed.
3. **Registry Tagging for Detection:** The installer must record which set of applications (or roles/toolsets) were installed in a custom registry key (e.g., under `HKLM:\SOFTWARE\CustomSOE\AdminTools`). The detection method will read this registry value to ascertain compliance.
4. **Embedded Configuration:** To allow the script to function as a standalone detection script in Intune without relying on external files in the same directory, the JSON configuration (tool definitions) must be embedded directly into the `.ps1` script (e.g., as a Here-String or PSCustomObject).
5. **Logging:** The script must provide detailed logging to a local directory (e.g., `C:\Windows\SOELogs`) to facilitate troubleshooting during and after Intune deployment.

## Architecture

### Components
1. **AdminToolManager.ps1:** The core execution engine.
   - Parses parameters (`ToolsetSelection`, `RoleSelection`).
   - Reads tool definitions (currently external, to be embedded).
   - Resolves composite toolsets into their atomic RSAT and Windows Feature components.
   - Executes `Add-WindowsCapability`, `Remove-WindowsCapability`, `Enable-WindowsOptionalFeature`, and `Disable-WindowsOptionalFeature` as necessary.
   - Writes detailed logs to track execution status and errors.
   - Implements registry tagging upon successful execution to support Intune detection.
2. **Tool Definitions (Configuration):**
   - **Toolsets:** Maps a logical name (e.g., `ActiveDirectory`) to its underlying RSAT capabilities (e.g., `Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0`) and Windows Features.
   - **CompositeToolsets:** Groups multiple atomic toolsets into a single deployable entity (e.g., `AllTools`).
   - **Roles:** Maps functional roles (e.g., `SOE`, `All`) to their required composite or atomic toolsets.
   - **Settings:** Defines global execution flags such as `AllowRestart`, `VerifyAfterChanges`, `IgnoreUnavailableComponents`, and `FailOnInstallationError`.

### Execution Flow (Intune Win32 App Deployment)
1. **Installation:**
   - Intune executes `AdminToolManager.ps1` with the desired parameters (e.g., `-RoleSelection SOE`).
   - The script initializes logging and loads the embedded JSON definitions.
   - The script resolves the required capabilities based on the selected role/toolset.
   - Missing capabilities/features are installed.
   - Upon successful installation of all required components, the script writes a success value to a designated registry key (e.g., `HKLM:\SOFTWARE\CustomSOE\AdminTools\Role = 'SOE'`).
2. **Detection:**
   - Intune evaluates the detection rules. This can be configured as a simple Registry check looking for the specific key/value pair created during installation, or as a custom PowerShell detection script.
   - If using a custom PowerShell detection script, the script utilizes the embedded JSON definition to query `Get-WindowsCapability` and `Get-WindowsOptionalFeature` directly, verifying that every component required by the specified role is currently installed. It may also verify the registry tag.

### Data Model
- **Atomic Toolset Definition:**
  ```json
  "ActiveDirectory": {
      "RSAT": ["Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"],
      "WindowsFeatures": []
  }
  ```
- **Role Definition:**
  ```json
  "SOE": [
      "ActiveDirectory",
      "GPMC",
      "DHCP"
  ]
  ```

## Future Considerations
- Transitioning the separate `ToollDefinitions.json` into an embedded variable within `AdminToolManager.ps1` to satisfy the Intune standalone detection script requirement.
- Adding comprehensive error handling and rollback mechanisms if a component fails to install during a multi-component deployment.

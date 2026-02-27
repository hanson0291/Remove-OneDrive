# Remove-OneDrive

A PowerShell script to fully uninstall Microsoft OneDrive from Windows, including a scheduled post-reboot cleanup task to remove leftover folders and files.

## Requirements

- Windows 10 or 11
- PowerShell 5.1+
- **Must be run as Administrator**

## Usage

Save the script as `Remove-OneDrive.ps1` and run it from an elevated PowerShell session.

### Basic uninstall (with interactive reboot prompt)

```powershell
.\Remove-OneDrive.ps1
```

### Uninstall and reboot automatically

```powershell
.\Remove-OneDrive.ps1 -Reboot
```

### Uninstall and block OneDrive from being reinstalled via Group Policy

```powershell
.\Remove-OneDrive.ps1 -BlockReinstall
```

### Combine flags

```powershell
.\Remove-OneDrive.ps1 -BlockReinstall -Reboot
```

## Parameters

| Parameter | Type | Description |
|---|---|---|
| `-Reboot` | Switch | Automatically reboots after scheduling the cleanup task |
| `-BlockReinstall` | Switch | Sets a Group Policy registry key (`DisableFileSyncNGSC`) to prevent OneDrive from being reinstalled |
| `-PostReboot` | Switch | **Internal use.** Run by the scheduled task after reboot to complete folder cleanup |
| `-UserProfilePath` | String | Override the user profile path used for cleanup (defaults to `$env:USERPROFILE`) |

## What it does

1. **Stops** the running OneDrive process
2. **Runs** `OneDriveSetup.exe /uninstall` from `System32` and/or `SysWOW64`
3. *(Optional)* **Blocks reinstall** via a registry policy key
4. **Schedules a post-reboot task** (runs as SYSTEM at startup) to remove leftover folders:
   - `%USERPROFILE%\OneDrive`
   - `%USERPROFILE%\AppData\Local\Microsoft\OneDrive`
   - `%ProgramData%\Microsoft OneDrive`
5. After reboot, the scheduled task **runs automatically** and deletes itself when done

## Notes

- The script must be saved and run from a `.ps1` file — it will not work when pasted directly into a PowerShell session, because it schedules itself as a post-reboot task using `$MyInvocation.MyCommand.Path`.
- The `-BlockReinstall` flag writes to `HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive`. This can be reversed by deleting that registry key.
- If you prefer not to reboot immediately, the cleanup task will run automatically on the next system startup.

## License

MIT

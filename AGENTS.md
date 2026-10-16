# DriveIt repository instructions

- Only when the user explicitly says **"OneDrive yükle"**, run `scripts/upload_latest_apk_to_onedrive.ps1` to copy the existing release APK into the detected OneDrive sync folder at `DriveIt/APK/DriveIt-Latest.apk`.
- Do not copy or upload APKs to OneDrive without that explicit user command.
- The OneDrive script must use an already-built release APK only; never build as part of an upload request. Report local hash verification separately from cloud synchronization, which must not be claimed unless independently verified.

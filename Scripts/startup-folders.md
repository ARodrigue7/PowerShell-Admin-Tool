# Startup Folders

List files found in the user and all-users startup folders.

```script-inputs
[
  {
    "Name": "IncludeFileHash",
    "Label": "Include SHA1 hash",
    "Type": "bool",
    "Default": true,
    "Help": "Turn this off to speed up collection on large folders."
  }
]
```

```powershell
param(
    [bool]$IncludeFileHash = $true
)

$startupFolders = @(
    @{
        Path        = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs\Startup'
        Description = 'User Startup Folder'
    },
    @{
        Path        = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\Start Menu\Programs\Startup'
        Description = 'All Users Startup Folder'
    }
)

foreach ($folder in $startupFolders) {
    if (-not (Test-Path -Path $folder.Path -PathType Container)) {
        continue
    }

    Get-ChildItem -Path $folder.Path -File | ForEach-Object {
        $hash = $null
        if ($IncludeFileHash) {
            try {
                $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA1 -ErrorAction Stop).Hash
            }
            catch {
                $hash = $null
            }
        }

        [PSCustomObject]@{
            CSName                   = $env:COMPUTERNAME
            StartupFolderPath        = $_.DirectoryName
            StartupFolderDescription = $folder.Description
            FileInfoName             = $_.Name
            FileInfoSize             = $_.Length
            LastWriteTime            = $_.LastWriteTime
            Hash                     = $hash
            Time                     = Get-Date
        }
    }
}
```

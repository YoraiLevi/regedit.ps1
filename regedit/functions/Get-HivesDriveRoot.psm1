function Get-HivesDriveRoot {
    $HivesDriveRoot = @{
        'HKCR:' = 'HKEY_CLASSES_ROOT'
        'HKCU:' = 'HKEY_CURRENT_USER'
        'HKLM:' = 'HKEY_LOCAL_MACHINE'
        'HKU:'  = 'HKEY_USERS'
        'HKCC:' = 'HKEY_CURRENT_CONFIG'
    }
    return $HivesDriveRoot
}
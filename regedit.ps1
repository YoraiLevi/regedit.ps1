<#
https://github.com/SegoCode/Reg-importer
https://github.com/UNT-CAS/ConvertFrom-Registry/blob/master/ConvertFrom-Registry.ps1
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-7.3
Get Values (Recursively if desired) from a Registry Key and return them as a Hashtable. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-5.1
https://support.microsoft.com/en-us/topic/how-to-add-modify-or-delete-registry-subkeys-and-values-by-using-a-reg-file-9c7f37cf-a5e9-e1cd-c4fa-2a26218a1a23#bkmk_syntax

https://ss64.com/nt/regedit.html
Export the Registry (all HKLM plus current user):
    REGEDIT /E pathname

    Export part of the Registry:
    REGEDIT /E pathname "RegPath"

    Export part of the Registry in ANSI mode:
    REGEDIT /A pathname "RegPath"
    (This is undocumented and will skip any unicode keys/values.)

    Import a reg script:
    REGEDIT pathname

    Silent import:
    REGEDIT /S pathname

    Start the regedit GUI:
    REGEDIT

    Open multiple copies of regedit:
    REGEDIT /m

https://ss64.com/nt/reg.html
   REG QUERY [ROOT\]RegKey /V ValueName [/s] [/F Data [/K] [/D] [/C] [/E]]
      [/T DataType] [/Z] [/SE Separator] [/reg:32 | /reg:64]

   REG QUERY [ROOT\]RegKey /VE  [/f Data [/K] [/D] [/C] [/E]]    -- /VE returns the (default) value
      [/T DataType] [/Z] [/SE Separator] [/reg:32 | /reg:64]      
   
   REG ADD [ROOT\]RegKey /V ValueName [/T DataType] [/S Separator] [/D Data] [/F] [/reg:32] [/reg:64]
   REG ADD [ROOT\]RegKey /VE [/d Data] [/F] [/reg:32 | /reg:64]

   REG DELETE [ROOT\]RegKey /V ValueName [/F]
   REG DELETE [ROOT\]RegKey /VE [/F]      -- Remove the (default) value
   REG DELETE [ROOT\]RegKey /VA [/F]      -- Delete all values under this key

   REG COPY  [\\SourceMachine\][ROOT\]RegKey [\\DestMachine\][ROOT\]RegKey

   REG EXPORT [ROOT\]RegKey FileName.reg [/Y] [/reg:32 | /reg:64]
   REG IMPORT FileName.reg  [/reg:32 | /reg:64]
   REG SAVE [ROOT\]RegKey FileName.hiv [/Y] [/reg:32 | /reg:64]
   REG RESTORE \\MachineName\[ROOT]\KeyName FileName.hiv [/reg:32 | /reg:64]
   
   REG LOAD KeyName FileName [/reg:32 | /reg:64]
   REG UNLOAD KeyName
   
   REG COMPARE [ROOT\]RegKey [ROOT\]RegKey [/V ValueName] [Output] [/s] [/reg:32 | /reg:64]
   REG COMPARE [ROOT\]RegKey [ROOT\]RegKey [/VE] [Output] [/s] [/reg:32 | /reg:64]


https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/reg
reg add 	Adds a new subkey or entry to the registry.
reg compare Compares specified registry subkeys or entries.
reg copy    Copies a registry entry to a specified location on the local or remote computer.
reg delete	Deletes a subkey or entries from the registry.
reg export	Copies the specified subkeys, entries, and values of the local computer into a file for transfer to other servers.
reg import	Copies the contents of a file that contains exported registry subkeys, entries, and values into the registry of the local computer.
reg load	Writes saved subkeys and entries into a different subkey in the registry.
reg query	Returns a list of the next tier of subkeys and entries that are located under a specified subkey in the registry.
reg restore	Writes saved subkeys and entries back to the registry.
reg save	Saves a copy of specified subkeys, entries, and values of the registry in a specified file.
reg unload	Removes a section of the registry that was loaded using the reg load operation.
#>
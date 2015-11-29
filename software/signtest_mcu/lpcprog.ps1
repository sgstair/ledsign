param([string]$progfile)

# Just be sure.
.\lpcfix $progfile


$disk = @(gwmi win32_diskdrive | where {$_.Model -eq "NXP LPC134X IFLASH USB Device"})
if($disk.count -eq 0) { write-host "Could not find NXP LPC134x drive"; exit 1; }
if($disk.count -gt 1) { write-host "Ambiguous operation: There are several LPCs attached."; exit 1; }

$partition = @($disk[0].getrelated("Win32_DiskPartition"))
if($partition.count -ne 1) { write-host "Unexpected failure: Could not find related partition"; exit 1; }

$logical = @($partition[0].GetRelated("Win32_LogicalDisk"))
if($logical.count -ne 1) { write-host "Unexpected failure: Could not find related logical disk"; exit 1; }

$drivebase = $logical[0].DeviceID;

write-host "Found NXP drive on $drivebase"

remove-item "$drivebase\firmware.bin"

copy-item $progfile "$drivebase\firmware.bin"

write-host "Firmware updated!"

exit 0;

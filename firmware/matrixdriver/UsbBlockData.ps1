# This powershell script generates the USB Descriptors for the FPGA firmware.
#
# The descriptor block take the following form (for xilinx_bram)
# Descriptor pointer table
#   An array of entries, one for each descriptor, with the following structure
#   1 byte: Offset in the block of this descriptor, in 4-byte steps. (0-1020)
#   1 byte: Length of this descriptor (0-255 bytes)
# For each descriptor, pointed to by the pointer table, the raw data to be sent out is stored.
# Other locations are set to zero.

# Configurable parameters that will be used to generate descriptor data.

try {

$outformat = "Xilinx_bram";
$blocksize = 1024;

$descriptors = {

  #VID/PID used here are arbitrary, unregistered. This is for testing purposes only.
  DeviceDescriptor -USBVID 0x544C -USBPID 0x4C73 -Product 1

  ConfigurationDescriptor { 
    PowerMa 100; 
    Interface -Class 0xFF {
      Endpoint In 1 Bulk 64;
      Endpoint Out 1 Bulk 64;
    }
  }


  OsWinusbDescriptor;

  OsExtendedPropertyDescriptor {
    StringProperty "DeviceInterfaceGUID" "{671a4aec-97ea-4345-83d9-f7e9e0b50ec7}";
  }
  
  StringOsDescriptor -VendorRequest 0xFE;
  
  StringDescriptorLangIds;
  
  StringDescriptor "LedSign Matrix Controller" # String 1

};


} catch {
  Write-host "Error in configuration data";
  write-host ($_ | fl | out-string);
  exit 1;
}  

# Now, the code that actually transforms the inputs into the output data.

trap {
  write-host "Exception while processing.";
  write-host ($_ | fl | out-string);
  exit 1;
}


$script:descriptordata = @();

function AppendDescriptor([byte[]]$descriptordata)
{
  $object = new-object PSObject -prop @{ Data = $descriptordata; Location = 0; Length = $descriptordata.Length; };
  $script:descriptordata += @($object);
}


$script:assembledata = $null
$script:assemblesize = 0;
function AssembleStart()
{
  $script:assembledata = new-object byte[] 512;
  $script:assemblesize = 0;
}
function AssembleAddBytes([byte[]]$bytes)
{
  [array]::Copy($bytes, 0, $assembledata, $assemblesize, $bytes.length);
  $script:assemblesize += $bytes.length;
}
function AssembleFinish()
{
  $data = new-object byte[] $assemblesize;
  [array]::Copy($assembledata, $data, $assemblesize);
  $script:assembledata = $null
  $script:assemblesize = 0;
  return $data;
}
function AssembleGetLocation()
{
  $assemblesize;
}
Function AssemblePatchByte($loc, $byte)
{
  $assembledata[$loc] = $byte;
}

function AddByte([Byte]$byte)
{
  AssembleAddBytes @($byte);
}
function AddWord([UInt16]$word)
{
  AssembleAddBytes ([bitconverter]::GetBytes($word));
}
function AddDword([UInt32]$dword)
{
  AssembleAddBytes ([bitconverter]::GetBytes($word));
}

function FixLength($data)
{
  $data[0] = $data.Length;
  $data;
}


function DeviceDescriptor($USBVID, $USBPID, 
  $Configurations = 1, $class=0, $subclass=0, $protocol=0, $ep0size=64, 
  $release = 0, $Manufacturer = 0, $Product = 0, $SerialNumber = 0)
{
  AssembleStart;
  AddByte 0; # Fix length later
  AddByte 1; # Device descriptor type
  AddWord 0x200; # USB 2.0
  AddByte $class;
  AddByte $subclass
  AddByte $protocol;
  AddByte $ep0Size;
  AddWord $USBVID;
  AddWord $USBPID;
  AddWord $release;
  AddByte $Manufacturer;
  AddByte $product;
  AddByte $SerialNumber;
  AddByte $Configurations;
  
  AppendDescriptor (FixLength (AssembleFinish));
}

function ConfigurationDescriptor($configurations)
{
  function PowerMa($ma) { $curcfg.Power = $ma; }
  function SelfPowered() { $curcfg.Attributes = $curcfg.Attributes -bor 0x40; }
  function RemoteWakeup() { $curcfg.Attributes = $curcfg.Attributes -bor 0x20; }
  function ConfigString($index) { $curcfg.String = $index; }
  function Value($index) { $curcfg.Value = $index; }
  
  function Interface($contents, $number=-1, $alternate=0, $class=0, $subclass=0, $protocol=0, $string=0)
  {
    if($number -eq -1) { $number = $curcfg.Interfaces; }
    if($number -eq $curcfg.Interfaces) { $curcfg.Interfaces++; }
    
    AddByte 9; # Interface length
    AddByte 4; # Interface type
    AddByte $number;
    AddByte $alternate;
    $fixup_endpoint_count = AssembleGetLocation;
    AddByte 0; # Endpoint count;
    AddByte $class;
    AddByte $subclass;
    AddByte $protocol;
    AddByte $string;
    
    $script:endpointcount = 0;
    
    foreach($ic in $contents)
    {
      & $ic;
    }
  
    AssemblePatchByte $fixup_endpoint_Count $endpointcount;
  }
  
  function Endpoint($direction, $endpointindex, $endpointtype, $packetsize, $interval=0)
  {
    $script:endpointcount++;
    Addbyte 7; # Endpoint Length
    AddByte 5; # Endpoint Type
    
    $address = $endpointindex
    switch($direction)
    { 
      "In" { $address = $address -bor 0x80; }
      "Out" { }
      default { throw "Unrecognized endpoint direction $direction" }
    }
    
    Addbyte $address;
    
    $attributes = 0;
    switch($endpointtype)
    {
      "Bulk" { $attributes = 2; }
      "Interrupt" { $attributes = 3; }
      "Isochronous" { throw "Isochronous endpoints are more complex and not supported yet." }
      default { throw "Unrecognized endpoint type $endpointtype" }
    }
    
    AddByte $attributes;
    
    AddWord $packetsize;
    AddByte $interval;
    
  }


  $configdata = @();
  foreach($cfg in $configurations)
  {
    $script:curcfg = new-object PSObject -prop @{ Power = 100; Attributes = 0x80; String = 0; Interfaces = 0; Value = 1; Data=$null }
    AssembleStart;
  
    & $cfg;
  
    $curcfg.Data = AssembleFinish;
    $configdata += @($curcfg);
  }

  AssembleStart;
  foreach($cfg in $configdata)
  {
    Addbyte 9; # Length
    Addbyte 2; # Configuration type
    $bytes = $cfg.Data.Length + 9;
    Addword $bytes; # Overall length of configuration
    AddByte $cfg.Interfaces;
    Addbyte $cfg.Value;
    AddByte $cfg.String;
    AddByte $cfg.Attributes;
    AddByte ([int]($cfg.Power/2));
    AssembleAddBytes $cfg.Data
  }
  AppendDescriptor (AssembleFinish);
}


# todo: Make this more generic.
function OsWinusbDescriptor()
{
  AppendDescriptor @(
  	0x28, 0x00, 0x00, 0x00, # 0x28 bytes
	0x00, 0x01, # BCD Version ( 0x0100 )
	0x04, 0x00, # wIndex (Extended compat ID)
	0x01,		# count
	0,0,0,0,0,0,0, # 7x reserved
	# Function section
	
	0x00,		# Interface number
	0x01,		# Reserved, must be 1
	[byte][char]'W', [byte][char]'I', [byte][char]'N', [byte][char]'U', [byte][char]'S', [byte][char]'B', 0, 0, # Compatible ID
	0,0,0,0,0,0,0,0, # Secondary ID
	0,0,0,0,0,0 # 6x Reserved
   );
}


function OsExtendedPropertyDescriptor([scriptblock]$properties)
{
  function StringProperty([string]$Key, [string]$Value)
  {
    $length = 14+4+($key.Length+$value.Length)*2;
    AddDword $length;
    AddDword 1; # REG_SZ
    AddWord (($key.Length+1)*2);
    foreach($c in [char[]]$key) { AddWord $c; }
    AddWord 0; # Terminate
    AddWord (($value.Length+1)*2);
    foreach($c in [char[]]$value) { AddWord $c; }
    AddWord 0; # Terminate
    
    $script:propertycount++;
  }

  AssembleStart;
  
  AddDword 0; # Length: fix this later.
  AddWord 0x0100; # Version 1.0
  AddWord 0; # Descriptor index
  $propcountloc = AssembleGetLocation
  AddWord 0; # Number of properties
  
  $script:propertycount = 0;
  
  & $properties
  
  AssemblePatchByte $propcountloc $propertycount
  if((AssembleGetLocation) -gt 255) { throw "Unable to deal with descriptors > 255 bytes currently." }
  AssemblePatchByte 0 (AssembleGetLocation);

  AppendDescriptor (AssembleFinish);

}

function StringDescriptorLangIds()
{
  AppendDescriptor @( 4, 3, 9, 4 ); # Only 0x0409 = English (United States)
}

function StringDescriptor([string]$string)
{
  AssembleStart;
  Addbyte 0; # Length will be fixed later
  AddByte 3; # String descriptor type
  
  foreach($c in [char[]]$string) { AddWord $c; }  
  
  AppendDescriptor (FixLength (AssembleFinish));
}

function StringOSDescriptor([byte] $VendorRequest)
{
  AssembleStart;
  Addbyte 0; # Length will be fixed later
  AddByte 3; # String descriptor type
  
  foreach($c in [char[]]"MSFT100") { AddWord $c; }
  
  AddByte $vendorrequest;
  AddByte 0;
  
  AppendDescriptor (FixLength (AssembleFinish));
}



# Evaluate descriptors list to generate descriptor data
& $descriptors;


# Output descriptor data according to output format.
if($outformat -eq "xilinx_bram")
{

  # Arrange descriptors in the output data
  $cursor = $descriptordata.Length*2;
  if(($cursor -band 2) -ne 0) { $cursor += 2; }
  
  foreach($d in $descriptordata)
  {
    $d.Location = $cursor;
    $cursor += $d.Length;
    while(($cursor -band 3) -ne 0) { $cursor++; }
  }

  $outblock = new-object byte[] $blocksize;
  
  $cursor = 0;
  foreach($d in $descriptordata)
  {
    $outblock[$cursor++] = ($d.Location / 4);
    $outblock[$cursor++] = $d.Length;

    write-host "Debug" ($d.Location) ($d.Length) "Data" (($d.Data | foreach {$_.ToString('x2')}) -join " ");
    [Array]::Copy($d.Data, 0, $outblock, $d.Location, $d.Length);
  }

  # Generate FPGA formatted text output.
  
  $cursor = 0;
  $loc = 0;
  $outstrings = @();
  while($cursor -lt $blocksize)
  {
    $row = $outblock[$cursor..($cursor+31)];
    [array]::Reverse($row);
    $rowhex = ($row | foreach {$_.ToString('x2')}) -join "";
    $rowstring = 'INIT_{0:X2} => X"{1}",' -f $loc, $rowhex;
    $outstrings += @($rowstring);
    
    $cursor += 32;
    $loc++;
  }
  
  write-host "";
  write-host ($outstrings -join "`n");
  write-host "";


}
else
{
  write-host "Error: Unsupported output format $outformat";
  exit 1;
}

exit 0;
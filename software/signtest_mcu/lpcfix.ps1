param([string]$fixfile)

$f = $null
trap 
{
  write-host (dir env: | out-string)
  write-host "Exception:"
  write-host ($_ | fl * | out-string);
  $f.Close();
  exit 1;
}

$fname = resolve-path $fixfile
$f = [io.file]::Open($fname,"Open","ReadWrite");

$br = new-object Io.BinaryReader ($f)

$data = 1..7 | foreach {$br.ReadUInt32()}

$check = ( ( ($data | measure -sum).sum  -bxor [uint32]"0xFFFFFFFF") + 1 ) -band [uint32]"0xFFFFFFFF";

$bw = new-object Io.BinaryWriter ($f)

$bw.Write([uint32]$check);

$f.close();

write-host ("Fixed. (new checksum {0:x8})" -f $check)

exit 0;
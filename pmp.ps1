param (
  [int]$sleep = 10,
  [int]$probes = 1,
  [string]$name = "mysqld",
  [bool]$show_lines=$FALSE,
  [bool]$only_my_code=$FALSE,
  [bool]$compact = $FALSE,
  [int]$min_threshold=1,
  [int]$id = 0
)

function skip_line($line)
{
   if (!$only_my_code)
   {
     return $FALSE;
   }
   $not_my_code= "ntdll!", "kernel32!","thread_start<","invoke_thread_procedure","pthread_start"
   foreach($substr in $not_my_code)
   {
     if ($line.Contains($substr))
     {
        return $TRUE;
     }
   }
}

function remove_module($line)
{
  $module_end = $line.IndexOf("!")
  if ($module_end -lt 0)
  {
    return $line
  }
  return $line.Substring($module_end +1)
}

if (-not (Get-Command "cdb.exe" -ErrorAction SilentlyContinue))
{ 
   "Can't find cdb.exe in PATH. Aborting"
   exit 1
}

if ($id -eq 0)
{
    $list = (Get-Process | Where-Object {$_.Name -eq $name})
    if ($list -eq $null)
    {
        "Process $name not found"
        exit 1
    }
    $id = $list[0].Id;
}

 if (Test-Path "cdb.log") 
 {
   Remove-Item "cdb.log"
 }

foreach($i in 1..$probes)
{
    "$i taking a dump"
    $dumpname = "$i.dmp"
    if (Test-Path $dumpname) 
    {
        Remove-Item $dumpname
    }
   
    &cdb.exe -pv -p $id  -c ".dump $i.dmp;q" |Out-File -Encoding ASCII  -append  -filepath cdb.log
    If($i -lt $probes)
    {
       sleep -s $sleep
    }
}


foreach($i in 1..$probes)
{
  if (!$show_lines)
  {
    $stack_command="~*kc;q";
  }
  else
  {
    $stack_command="~*k;q";
  } 
   &cdb.exe -lines -z "$i.dmp" -c "$stack_command" | Out-File -Encoding ASCII  -append -filepath cdb.log
}

$content = Get-Content "cdb.log"
$stack=""
$hash = @{}
$inStack = 0

$offset = 0;
foreach($line  in $content)
{
  #Write-Host $tokens.Count
  $off = $line.IndexOf("Call Site");
  if ($off -ge 0)
  {
    $offset = $off;
    $inStack = 1
  }
  elseif (($line -eq "") -or ($line -eq ("quit:"))) 
  {
    if ($stack.Length -gt 0)
    {
      $value = $hash[$stack]
      if (!$value)
      {
         $hash[$stack]=1
      }    
      else
      {
         $hash[$stack]= $value +1
      }
    }
    $inStack = 0

    $stack = ""
  }
  else
  {
     $skip = skip_line($line)
     if($inStack -and (!$skip))
     {
        $callstackFrame = $line.substring($offset)
        $callstackFrame = remove_module($callstackFrame);
        if ($stack.Length -gt 0)
        {
            $stack += "`r`n"
        }
        $stack +=$callstackFrame;
     }
  }
}

$sorted_hash = @{}
foreach ($k in $hash.Keys)
{
  $sorted_hash[$hash[$k]] +=,$k;
}

foreach($cnt in ($sorted_hash.Keys|Sort-Object -Descending))
{
  if ($cnt -lt $min_threshold)
  {
    break;
  }
  foreach($stack in $sorted_hash[$cnt])
  {
    if ($compact)
    {
      "" + $cnt  + " " + $stack.Replace("`r`n",",")
    }
    else
    {
      "$cnt"
      $stack
      ""
    }
  }
}

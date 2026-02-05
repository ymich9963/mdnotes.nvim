 param (
    [string]$assets_path = ""
 )

if ($assets_path -eq "")
{
    Write-Error "Option '-assets-path' cannot be blank"
    exit 1
}

$out = ""

if ($img = Get-Clipboard -Format Image -ErrorAction SilentlyContinue)
{
    $date = (Get-Date).ToString('HHmmssddMMyyyy')
    $path= -join($assets_path,"screenshot",$date,".png");
    $img.Save($path);
    $out = $path
} else {
    $out = Get-Clipboard -Format FileDropList -Raw
}

Write-Output $out
exit 0

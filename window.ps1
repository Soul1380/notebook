param([string]$Action,[string]$Pinned,[int]$OriginX=0,[int]$OriginY=0)
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class NotebookWindow {
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][NotebookWindow]::SetProcessDPIAware()
$found=[IntPtr]::Zero
for($attempt=0;$attempt -lt 80 -and $found -eq [IntPtr]::Zero;$attempt++){
  [NotebookWindow]::EnumWindows({param($h,$p) $t=New-Object System.Text.StringBuilder 512;[void][NotebookWindow]::GetWindowText($h,$t,$t.Capacity);if([NotebookWindow]::IsWindowVisible($h) -and $t.ToString() -match '^Notebook -'){$script:found=$h;return $false};return $true},[IntPtr]::Zero)|Out-Null
  if($found -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100}
}
if($found -eq [IntPtr]::Zero){Write-Error 'Notebook window not found';exit 1}
switch($Action){
  'restore' {if([NotebookWindow]::IsIconic($found)){[void][NotebookWindow]::ShowWindow($found,9)};[void][NotebookWindow]::SetForegroundWindow($found)}
  'animate' {
    [void][NotebookWindow]::ShowWindow($found,9)
    $screen=[System.Windows.Forms.Screen]::FromPoint((New-Object System.Drawing.Point($OriginX,$OriginY))).WorkingArea
    $w=[Math]::Min(1100,[int]($screen.Width*0.86));$h=[Math]::Min(800,[int]($screen.Height*0.86));$x=$screen.Left+[int](($screen.Width-$w)/2);$y=$screen.Top+[int](($screen.Height-$h)/2)
    # Set the final rectangle once. Repeatedly resizing a live browser window can leave its compositor behind the frame.
    [void][NotebookWindow]::SetWindowPos($found,[IntPtr]::Zero,$x,$y,$w,$h,4)
    [void][NotebookWindow]::SetForegroundWindow($found)
  }
  'minimize' {[void][NotebookWindow]::ShowWindow($found,6)}
  'maximize' {if([NotebookWindow]::IsZoomed($found)){[void][NotebookWindow]::ShowWindow($found,9)}else{[void][NotebookWindow]::ShowWindow($found,3)}}
  'pin' {$order=if($Pinned -eq 'true'){[IntPtr](-1)}else{[IntPtr](-2)};if(-not [NotebookWindow]::SetWindowPos($found,$order,0,0,0,0,3)){exit 1}}
}

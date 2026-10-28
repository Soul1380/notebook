param([string]$Action,[string]$Pinned)
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
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
$found = [IntPtr]::Zero
[NotebookWindow]::EnumWindows({param($h,$p) $t=New-Object System.Text.StringBuilder 512; [void][NotebookWindow]::GetWindowText($h,$t,$t.Capacity); if ([NotebookWindow]::IsWindowVisible($h) -and $t.ToString() -match '^Notebook -') { $script:found=$h; return $false }; return $true},[IntPtr]::Zero) | Out-Null
if ($found -eq [IntPtr]::Zero) { Write-Error '找不到手写笔记本窗口'; exit 1 }
switch ($Action) {
  'restore' { [void][NotebookWindow]::ShowWindow($found,9) }
  'minimize' { [void][NotebookWindow]::ShowWindow($found,6) }
  'maximize' { if ([NotebookWindow]::IsZoomed($found)) {[void][NotebookWindow]::ShowWindow($found,9)} else {[void][NotebookWindow]::ShowWindow($found,3)} }
  'pin' { $order=if($Pinned -eq 'true') {[IntPtr](-1)} else {[IntPtr](-2)}; if(-not [NotebookWindow]::SetWindowPos($found,$order,0,0,0,0,3)){exit 1} }
}



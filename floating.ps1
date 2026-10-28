Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$mutex = New-Object System.Threading.Mutex($false, 'Local\HandwritingNotebookFloatingBall')
if (-not $mutex.WaitOne(0, $false)) { exit }
try {
  $form = New-Object System.Windows.Forms.Form
  $form.FormBorderStyle='None'; $form.ShowInTaskbar=$false; $form.TopMost=$true; $form.StartPosition='Manual'
  $form.ClientSize=New-Object System.Drawing.Size(54,54); $form.BackColor=[System.Drawing.Color]::FromArgb(38,63,53)
  $form.ForeColor=[System.Drawing.Color]::White; $form.Cursor=[System.Windows.Forms.Cursors]::Hand
  $path=New-Object System.Drawing.Drawing2D.GraphicsPath; $path.AddEllipse(0,0,53,53); $form.Region=New-Object System.Drawing.Region($path)
  $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $form.Location=New-Object System.Drawing.Point(($bounds.Right-54),($bounds.Top+[int]($bounds.Height/2)-27))
  $script:dock='right'; $script:dragging=$false; $script:moved=$false; $script:expanded=$true
  $form.Add_Paint({param($sender,$e) $font=New-Object System.Drawing.Font('Segoe UI',19);$sf=New-Object System.Drawing.StringFormat;$sf.Alignment='Center';$sf.LineAlignment='Center';$rect=New-Object System.Drawing.RectangleF(0,0,[single]$sender.ClientSize.Width,[single]$sender.ClientSize.Height);$e.Graphics.DrawString([string][char]0x270E,$font,[System.Drawing.Brushes]::White,$rect,$sf);$font.Dispose();$sf.Dispose()})
  $script:openNotebook={
    $client=New-Object System.Net.Sockets.TcpClient
    try {$client.Connect('127.0.0.1',17683);$running=$true} catch {$running=$false} finally {$client.Dispose()}
    if (-not $running) {$node=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe';if(!(Test-Path $node)){$node='node.exe'};Start-Process -FilePath $node -ArgumentList ('"'+(Join-Path $PSScriptRoot 'desktop.cjs')+'"') -WindowStyle Hidden}
    $scriptPath=Join-Path $PSScriptRoot 'window.ps1'
    $windowAction=if($running){'restore'}else{'animate'}
    $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$scriptPath+'" '+$windowAction+' false '+($form.Left+27)+' '+($form.Top+27)
    Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden
  }
  $menu=New-Object System.Windows.Forms.ContextMenuStrip
  [void]$menu.Items.Add('Open notebook',$null,[System.EventHandler]{& $script:openNotebook})
  [void]$menu.Items.Add('Exit',$null,[System.EventHandler]{$form.Close()});$form.ContextMenuStrip=$menu
  $form.Add_MouseDown({param($s,$e) if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left){$script:dragging=$true;$script:moved=$false;$script:mouseStart=[System.Windows.Forms.Cursor]::Position;$script:formStart=$form.Location;$form.Capture=$true}})
  $form.Add_MouseMove({param($s,$e) if($script:dragging){$cur=[System.Windows.Forms.Cursor]::Position;$dx=$cur.X-$script:mouseStart.X;$dy=$cur.Y-$script:mouseStart.Y;if([Math]::Abs($dx)+[Math]::Abs($dy) -gt 3){$script:moved=$true;$script:dock='none'};if($script:moved){$form.Location=New-Object System.Drawing.Point(($script:formStart.X+$dx),($script:formStart.Y+$dy))}}})
  $form.Add_MouseUp({param($s,$e) if($e.Button -ne [System.Windows.Forms.MouseButtons]::Left){return};$script:dragging=$false;$form.Capture=$false;if(-not $script:moved){& $script:openNotebook;return};$screen=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).WorkingArea;$left=[Math]::Abs($form.Left-$screen.Left);$right=[Math]::Abs($screen.Right-$form.Right);if([Math]::Min($left,$right) -le 45){if($left -le $right){$script:dock='left';$form.Left=$screen.Left}else{$script:dock='right';$form.Left=$screen.Right-$form.Width};$form.Top=[Math]::Max($screen.Top,[Math]::Min($form.Top,$screen.Bottom-$form.Height));$script:expanded=$true}else{$script:dock='none'}})
  $timer=New-Object System.Windows.Forms.Timer;$timer.Interval=16
  $timer.Add_Tick({if($script:dragging -or $script:dock -eq 'none' -or $menu.Visible){return};$screen=[System.Windows.Forms.Screen]::FromControl($form).WorkingArea;$mouse=[System.Windows.Forms.Cursor]::Position;$hover=$form.Bounds.Contains($mouse);if($hover){$script:expanded=$true}elseif($mouse.Y -lt $form.Top-12 -or $mouse.Y -gt $form.Bottom+12 -or $mouse.X -lt $form.Left-12 -or $mouse.X -gt $form.Right+12){$script:expanded=$false};if($script:dock -eq 'left'){$target=if($script:expanded){$screen.Left}else{$screen.Left-$form.Width+10}}else{$target=if($script:expanded){$screen.Right-$form.Width}else{$screen.Right-10}};$delta=$target-$form.Left;if($delta -ne 0){$step=[int][Math]::Sign($delta)*[Math]::Max(1,[Math]::Ceiling([Math]::Abs($delta)*0.22));$form.Left+=$step}})
  $timer.Start();[System.Windows.Forms.Application]::Run($form);$timer.Stop();$timer.Dispose()
} finally {$mutex.ReleaseMutex();$mutex.Dispose()}

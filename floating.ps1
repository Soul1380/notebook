Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$mutex = New-Object System.Threading.Mutex($false, 'Local\HandwritingNotebookFloatingBall')
if (-not $mutex.WaitOne(0, $false)) { exit }
try {
  $form = New-Object System.Windows.Forms.Form
  $form.FormBorderStyle = 'None'; $form.ShowInTaskbar = $false; $form.TopMost = $true
  $form.StartPosition = 'Manual'; $form.Size = New-Object System.Drawing.Size(54,54)
  $form.BackColor = [System.Drawing.Color]::FromArgb(38,63,53)
  $form.ForeColor = [System.Drawing.Color]::White
  $form.Cursor = [System.Windows.Forms.Cursors]::Hand
  $form.Opacity = 0.96
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(0,0,53,53); $form.Region = New-Object System.Drawing.Region($path)
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $form.Location = New-Object System.Drawing.Point(($bounds.Right-54),($bounds.Top+[int]($bounds.Height/2)-27))
  $script:dock = 'right'; $script:dragging = $false; $script:moved = $false
  $form.Add_Paint({ param($sender,$e) $font=New-Object System.Drawing.Font('Segoe UI',19,[System.Drawing.FontStyle]::Regular); $sf=New-Object System.Drawing.StringFormat; $sf.Alignment='Center'; $sf.LineAlignment='Center'; $e.Graphics.DrawString([string][char]0x270E,$font,[System.Drawing.Brushes]::White,$sender.ClientRectangle,$sf); $font.Dispose(); $sf.Dispose() })
  $menu = New-Object System.Windows.Forms.ContextMenuStrip
  [void]$menu.Items.Add('Open notebook', $null, [System.EventHandler]{ & $script:openNotebook })
  [void]$menu.Items.Add('Exit', $null, [System.EventHandler]{ $form.Close() })
  $form.ContextMenuStrip = $menu
  $script:openNotebook = {
    $client=New-Object System.Net.Sockets.TcpClient
    try { $client.Connect('127.0.0.1',17683); $running=$true } catch { $running=$false } finally { $client.Dispose() }
    if ($running) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'window.ps1') 'restore' 'false' }
    else { $node=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'; if (!(Test-Path $node)) {$node='node.exe'}; Start-Process -FilePath $node -ArgumentList ('"' + (Join-Path $PSScriptRoot 'desktop.cjs') + '"') -WindowStyle Hidden }
  }
  $form.Add_MouseDown({param($s,$e) if($e.Button -eq 'Left'){$script:dragging=$true;$script:moved=$false;$script:mouseStart=[System.Windows.Forms.Cursor]::Position;$script:formStart=$form.Location}})
  $form.Add_MouseMove({param($s,$e) if($script:dragging){$cur=[System.Windows.Forms.Cursor]::Position;$dx=$cur.X-$script:mouseStart.X;$dy=$cur.Y-$script:mouseStart.Y;if([Math]::Abs($dx)+[Math]::Abs($dy) -gt 4){$script:moved=$true};if($script:moved){$form.Location=New-Object System.Drawing.Point(($script:formStart.X+$dx),($script:formStart.Y+$dy))}}})
  $form.Add_MouseUp({param($s,$e) if($e.Button -ne 'Left'){return};$script:dragging=$false;if(-not $script:moved){& $script:openNotebook;return};$screen=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).WorkingArea;$left=[Math]::Abs($form.Left-$screen.Left);$right=[Math]::Abs($screen.Right-$form.Right);if([Math]::Min($left,$right) -le 35){if($left -le $right){$script:dock='left';$form.Left=$screen.Left}else{$script:dock='right';$form.Left=$screen.Right-$form.Width};$form.Top=[Math]::Max($screen.Top,[Math]::Min($form.Top,$screen.Bottom-$form.Height))}else{$script:dock='none'}})
  $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=150
  $timer.Add_Tick({if($script:dragging -or $script:dock -eq 'none' -or $menu.Visible){return};$screen=[System.Windows.Forms.Screen]::FromControl($form).WorkingArea;$mouse=[System.Windows.Forms.Cursor]::Position;$hover=$form.Bounds.Contains($mouse);if($script:dock -eq 'left'){$form.Left=if($hover){$screen.Left}else{$screen.Left-$form.Width+10}}else{$form.Left=if($hover){$screen.Right-$form.Width}else{$screen.Right-10}}})
  $timer.Start(); [System.Windows.Forms.Application]::Run($form); $timer.Stop(); $timer.Dispose()
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }

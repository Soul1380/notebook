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
  $skinFile=Join-Path $PSScriptRoot '.ball-settings.json'
  $script:setSkin={param([System.Drawing.Color]$c) $form.BackColor=$c; $lum=(0.299*$c.R+0.587*$c.G+0.114*$c.B);$form.ForeColor=if($lum -gt 150){[System.Drawing.Color]::FromArgb(35,51,42)}else{[System.Drawing.Color]::White};$form.Invalidate();try{ @{color=('#{0:X2}{1:X2}{2:X2}' -f $c.R,$c.G,$c.B)} | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 $skinFile } catch {}}
  try {if(Test-Path -LiteralPath $skinFile){$saved=Get-Content -LiteralPath $skinFile -Raw -Encoding UTF8 | ConvertFrom-Json;if($saved.color -match '^#[0-9a-fA-F]{6}$'){& $script:setSkin ([System.Drawing.ColorTranslator]::FromHtml($saved.color))}}} catch {}
  $form.Add_Paint({param($sender,$e) $font=New-Object System.Drawing.Font('Segoe UI',19);$sf=New-Object System.Drawing.StringFormat;$sf.Alignment='Center';$sf.LineAlignment='Center';$rect=New-Object System.Drawing.RectangleF(0,0,[single]$sender.ClientSize.Width,[single]$sender.ClientSize.Height);$brush=New-Object System.Drawing.SolidBrush($sender.ForeColor);$e.Graphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias;$e.Graphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit;$e.Graphics.DrawString([string][char]0x270E,$font,$brush,$rect,$sf);$brush.Dispose();$font.Dispose();$sf.Dispose()})
  $script:backendStarting=$false
  $script:openNotebook={param([bool]$preload=$false)
    $client=New-Object System.Net.Sockets.TcpClient
    try {$client.Connect('127.0.0.1',17683);$running=$true} catch {$running=$false} finally {$client.Dispose()}
    if($running){$script:backendStarting=$false}
    if($script:backendStarting -and ((Get-Date)-$script:backendStartTime).TotalSeconds -gt 15){$script:backendStarting=$false}
    if (-not $running -and -not $script:backendStarting) {
      $node=Join-Path $PSScriptRoot 'HandwritingNotebookBackend.exe';if(!(Test-Path $node)){$node=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe';if(!(Test-Path $node)){$node='node.exe'}}
      $screen=[System.Windows.Forms.Screen]::FromControl($form).WorkingArea;$w=[int][Math]::Min(1100,$screen.Width*0.86);$h=[int][Math]::Min(800,$screen.Height*0.86);$x=$screen.Left+[int](($screen.Width-$w)/2);$y=$screen.Top+[int](($screen.Height-$h)/2)
      $nodeArgs='"'+(Join-Path $PSScriptRoot 'desktop.cjs')+'" --position='+$x+','+$y+' --size='+$w+','+$h
      if($preload){$nodeArgs+=' --preload'}
      $script:backendStarting=$true;$script:backendStartTime=Get-Date;Start-Process -FilePath $node -ArgumentList $nodeArgs -WindowStyle Hidden
    } elseif (-not $preload) {
      $script:backendStarting=$false;$scriptPath=Join-Path $PSScriptRoot 'window.ps1';$args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$scriptPath+'" restore false'
      Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden
    }
  }
  $form.Add_Shown({& $script:openNotebook $true})
  $menu=New-Object System.Windows.Forms.ContextMenuStrip
  [void]$menu.Items.Add('打开笔记本',$null,[System.EventHandler]{& $script:openNotebook})
  [void]$menu.Items.Add('打开软件所在目录',$null,[System.EventHandler]{Start-Process -FilePath explorer.exe -ArgumentList ('"'+$PSScriptRoot+'"')})
  $skinMenu=New-Object System.Windows.Forms.ToolStripMenuItem('皮肤颜色')
  $choices=@(@('森林绿','#263F35'),@('海洋蓝','#315C87'),@('薰衣草','#76639B'),@('暖珊瑚','#C46B5E'),@('奶油白','#F3EBDD'),@('炭黑','#30343A'))
  foreach($choice in $choices){$item=New-Object System.Windows.Forms.ToolStripMenuItem($choice[0]);$item.Tag=$choice[1];$item.Add_Click({param($sender,$e) & $script:setSkin ([System.Drawing.ColorTranslator]::FromHtml([string]$sender.Tag))});[void]$skinMenu.DropDownItems.Add($item)}
  $custom=New-Object System.Windows.Forms.ToolStripMenuItem('自定义颜色…');$custom.Add_Click({$dialog=New-Object System.Windows.Forms.ColorDialog;$dialog.FullOpen=$true;$dialog.Color=$form.BackColor;if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){& $script:setSkin $dialog.Color};$dialog.Dispose()});[void]$skinMenu.DropDownItems.Add($custom);[void]$menu.Items.Add($skinMenu)
  [void]$menu.Items.Add('退出笔记本（关闭所有进程）',$null,[System.EventHandler]{
    $probe=New-Object System.Net.Sockets.TcpClient
    try{$probe.Connect('127.0.0.1',17683);$serverRunning=$true}catch{$serverRunning=$false}finally{$probe.Dispose()}
    if($serverRunning){
      try{$session=Get-Content -LiteralPath (Join-Path $PSScriptRoot '.notebook-session.json') -Raw -Encoding UTF8 | ConvertFrom-Json;if($session.key -notmatch '^[0-9a-f]{64}$'){throw '无法确认笔记本进程'};$reply=Invoke-RestMethod -Uri 'http://127.0.0.1:17683/shutdown' -Method Post -Headers @{'X-Notebook-Shutdown'=$session.key} -TimeoutSec 5;if(-not $reply.ok){throw '关闭失败'}}
      catch{[void][System.Windows.Forms.MessageBox]::Show('无法关闭笔记本窗口和后台进程。请先关闭笔记本窗口，再退出浮动球。','退出失败');return}
    }
    $form.Close()
  });$form.ContextMenuStrip=$menu
  $form.Add_MouseDown({param($s,$e) if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left){$script:dragging=$true;$script:moved=$false;$script:mouseStart=[System.Windows.Forms.Cursor]::Position;$script:formStart=$form.Location;$form.Capture=$true}})
  $form.Add_MouseMove({param($s,$e) if($script:dragging){$cur=[System.Windows.Forms.Cursor]::Position;$dx=$cur.X-$script:mouseStart.X;$dy=$cur.Y-$script:mouseStart.Y;if([Math]::Abs($dx)+[Math]::Abs($dy) -gt 3){$script:moved=$true;$script:dock='none'};if($script:moved){$form.Location=New-Object System.Drawing.Point(($script:formStart.X+$dx),($script:formStart.Y+$dy))}}})
  $form.Add_MouseUp({param($s,$e) if($e.Button -ne [System.Windows.Forms.MouseButtons]::Left){return};$script:dragging=$false;$form.Capture=$false;if(-not $script:moved){& $script:openNotebook;return};$screen=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).WorkingArea;$left=[Math]::Abs($form.Left-$screen.Left);$right=[Math]::Abs($screen.Right-$form.Right);if([Math]::Min($left,$right) -le 45){if($left -le $right){$script:dock='left';$form.Left=$screen.Left}else{$script:dock='right';$form.Left=$screen.Right-$form.Width};$form.Top=[Math]::Max($screen.Top,[Math]::Min($form.Top,$screen.Bottom-$form.Height));$script:expanded=$true}else{$script:dock='none'}})
  $timer=New-Object System.Windows.Forms.Timer;$timer.Interval=16
  $timer.Add_Tick({$exitRequest=Join-Path $PSScriptRoot '.update-exit-request';if(Test-Path -LiteralPath $exitRequest){try{$request=Get-Content -LiteralPath $exitRequest -Raw -Encoding UTF8;$session=Get-Content -LiteralPath (Join-Path $PSScriptRoot '.notebook-session.json') -Raw -Encoding UTF8|ConvertFrom-Json;if($request.Trim() -eq $session.key){Remove-Item -LiteralPath $exitRequest -Force;$form.Close();return}}catch{}};if($script:dragging -or $script:dock -eq 'none' -or $menu.Visible){return};$screen=[System.Windows.Forms.Screen]::FromControl($form).WorkingArea;$mouse=[System.Windows.Forms.Cursor]::Position;$hover=$form.Bounds.Contains($mouse);if($hover){$script:expanded=$true}elseif($mouse.Y -lt $form.Top-12 -or $mouse.Y -gt $form.Bottom+12 -or $mouse.X -lt $form.Left-12 -or $mouse.X -gt $form.Right+12){$script:expanded=$false};if($script:dock -eq 'left'){$target=if($script:expanded){$screen.Left}else{$screen.Left-$form.Width+10}}else{$target=if($script:expanded){$screen.Right-$form.Width}else{$screen.Right-10}};$delta=$target-$form.Left;if($delta -ne 0){$step=[int][Math]::Sign($delta)*[Math]::Max(1,[Math]::Ceiling([Math]::Abs($delta)*0.22));$form.Left+=$step}})
  $noticeTimer=New-Object System.Windows.Forms.Timer;$noticeTimer.Interval=2000
  $noticeTimer.Add_Tick({
    $notice=Join-Path $PSScriptRoot '.report-notice.json';$settings=Join-Path $PSScriptRoot '.report-settings.json'
    if(!(Test-Path -LiteralPath $notice)){return}
    try{
      $enabled=$true;if(Test-Path -LiteralPath $settings){$enabled=(Get-Content -LiteralPath $settings -Raw -Encoding UTF8|ConvertFrom-Json).enabled -eq $true};if(!$enabled){return}
      $item=Get-Item -LiteralPath $notice;if($item.Length -gt 16384){return}
      $data=Get-Content -LiteralPath $notice -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]::IsNullOrWhiteSpace([string]$data.title)){return}
      $title=([string]$data.title);if($title.Length -gt 100){$title=$title.Substring(0,100)}
      $location=[string]$data.path;if($location.Length -gt 500){$location=$location.Substring(0,500)}
      Remove-Item -LiteralPath $notice -Force -ErrorAction Stop
      $script:expanded=$true;$form.Activate();$noticeTimer.Stop()
      $message='有新的报表：'+$title;if($location){$message+="`r`n`r`n报表位置："+$location}
      [void][System.Windows.Forms.MessageBox]::Show($message,'手写笔记本 · 报表提醒',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
      $noticeTimer.Start()
    }catch{}
  })
  $timer.Start();$noticeTimer.Start();[System.Windows.Forms.Application]::Run($form);$noticeTimer.Stop();$noticeTimer.Dispose();$timer.Stop();$timer.Dispose()
} finally {$mutex.ReleaseMutex();$mutex.Dispose()}


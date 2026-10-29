param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Archive,[Parameter(Mandatory=$true)][string]$Sha256,[Parameter(Mandatory=$true)][string]$ExpectedVersion,[int]$BackendPid=0,[switch]$NoRestart)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Windows.Forms
$rootPath=[IO.Path]::GetFullPath($Root).TrimEnd('\')
$archivePath=[IO.Path]::GetFullPath($Archive)
$cachePath=[IO.Path]::GetFullPath((Join-Path $rootPath '.update-cache')).TrimEnd('\')+'\'
try {
  if(-not $archivePath.StartsWith($cachePath,[StringComparison]::OrdinalIgnoreCase)){throw '更新包路径无效'}
  if($Sha256 -notmatch '^[0-9a-fA-F]{64}$' -or (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $Sha256){throw '更新包校验失败'}
  if($ExpectedVersion -notmatch '^\d+\.\d+\.\d+$'){throw '更新版本无效'}
  if($BackendPid -gt 0){Wait-Process -Id $BackendPid -Timeout 25 -ErrorAction SilentlyContinue;if(Get-Process -Id $BackendPid -ErrorAction SilentlyContinue){throw '笔记本未能退出，更新已取消'}}
  $launcher=[IO.Path]::GetFullPath((Join-Path $rootPath 'HandwritingNotebook.exe'))
  for($i=0;$i -lt 30;$i++){ $running=@(Get-Process -Name 'HandwritingNotebook' -ErrorAction SilentlyContinue | Where-Object {try{[IO.Path]::GetFullPath($_.Path) -eq $launcher}catch{$false}});if(!$running.Count){break};Start-Sleep -Milliseconds 500 }
  if($running.Count){throw '启动器尚未退出，更新已取消'}
  if(-not $NoRestart -and !(Test-Path -LiteralPath $launcher)){throw '找不到笔记本启动器'}
  $allowed=@('index.html','styles.css','app.js','preferences.js','colors.js','files.js','interaction.js','desktop.cjs','floating.ps1','tasks.ps1','window.ps1','updater.cjs','apply-update.ps1','version.json','README.md','notebook.ico','HandwritingNotebook.exe','HandwritingNotebookBackend.exe')
  $token=[guid]::NewGuid().ToString('N');$staging=Join-Path $cachePath ('staging-'+$token);$backup=Join-Path $cachePath ('backup-'+$token);New-Item -ItemType Directory -Path $staging,$backup | Out-Null
  $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase);$total=0L
  $zip=[IO.Compression.ZipFile]::OpenRead($archivePath)
  try{foreach($entry in $zip.Entries){$name=$entry.FullName;if($name -notin $allowed -or $name.Contains('/') -or $name.Contains('\') -or -not $seen.Add($name)){throw '更新包包含不允许的文件'};$total+=$entry.Length;if($total -gt 250MB){throw '更新包解压后过大'};[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $staging $name),$false)}}finally{$zip.Dispose()}
  if(-not $seen.Contains('version.json') -or $seen.Count -lt 2){throw '更新包内容不完整'}
  $v=Get-Content -LiteralPath (Join-Path $staging 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if($v.version -ne $ExpectedVersion){throw '更新包版本不匹配'}
  $installed=New-Object 'System.Collections.Generic.List[string]';$existed=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  try {foreach($name in $seen){$dest=Join-Path $rootPath $name;if(Test-Path -LiteralPath $dest -PathType Leaf){Copy-Item -LiteralPath $dest -Destination (Join-Path $backup $name);[void]$existed.Add($name)};$installed.Add($name);Copy-Item -LiteralPath (Join-Path $staging $name) -Destination $dest -Force}}
  catch {foreach($name in $installed){$dest=Join-Path $rootPath $name;if($existed.Contains($name)){Copy-Item -LiteralPath (Join-Path $backup $name) -Destination $dest -Force}else{Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue}};throw}
  if(-not $NoRestart){try{Start-Process -FilePath $launcher -WindowStyle Hidden}catch{[void][System.Windows.Forms.MessageBox]::Show('更新已安装，但未能自动启动。请手动打开笔记本。','手写笔记本更新')}}
} catch { $message=$_.Exception.Message;try{[IO.File]::WriteAllText((Join-Path $cachePath 'update-error.txt'),$message)}catch{};if(-not $NoRestart){[void][System.Windows.Forms.MessageBox]::Show('更新失败：'+$message+'。原来的程序文件已保留或恢复。','手写笔记本更新')};exit 1 }

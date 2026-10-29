param(
  [Parameter(Mandatory=$true)][string]$NodePath,
  [Parameter(Mandatory=$true)][string]$StagePath,
  [Parameter(Mandatory=$true)][string]$InstallerPath
)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(!(Test-Path -LiteralPath $compiler)){throw 'C# compiler not found'}
if(!(Test-Path -LiteralPath $NodePath)){throw 'Node runtime not found'}
New-Item -ItemType Directory -Force -Path $StagePath | Out-Null
$sourceFiles=@('index.html','styles.css','app.js','preferences.js','colors.js','files.js','interaction.js','desktop.cjs','floating.ps1','tasks.ps1','window.ps1','README.md','notebook.ico')
$allowed=@($sourceFiles)+@('HandwritingNotebook.exe','HandwritingNotebookBackend.exe')
$unexpected=@(Get-ChildItem -LiteralPath $StagePath -Force | Where-Object { $_.Name -notin $allowed -or $_.PSIsContainer })
if($unexpected.Count -gt 0){throw 'Build stage contains unexpected files; choose an empty staging folder.'}
foreach($name in $sourceFiles){Copy-Item -LiteralPath (Join-Path $project $name) -Destination (Join-Path $StagePath $name) -Force}
Copy-Item -LiteralPath $NodePath -Destination (Join-Path $StagePath 'HandwritingNotebookBackend.exe') -Force
$icon=Join-Path $PSScriptRoot 'notebook.ico'
$launcher=Join-Path $StagePath 'HandwritingNotebook.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32icon:$icon" "/out:$launcher" (Join-Path $PSScriptRoot 'Launcher.cs')
if($LASTEXITCODE -ne 0){throw 'Launcher compilation failed'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$payload=Join-Path (Split-Path -Parent $StagePath) 'NotebookPayload.zip'
if(Test-Path -LiteralPath $payload){Remove-Item -LiteralPath $payload -Force}
[System.IO.Compression.ZipFile]::CreateFromDirectory($StagePath,$payload,[System.IO.Compression.CompressionLevel]::Optimal,$false)
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/win32icon:$icon" "/resource:$payload,NotebookPayload.zip" "/out:$InstallerPath" (Join-Path $PSScriptRoot 'Installer.cs')
if($LASTEXITCODE -ne 0){throw 'Installer compilation failed'}
Get-Item -LiteralPath $InstallerPath | Select-Object FullName,Length

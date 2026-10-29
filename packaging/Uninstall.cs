using System;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
internal static class Uninstall {
  internal static readonly string[] Files={"index.html","styles.css","app.js","preferences.js","colors.js","files.js","interaction.js","desktop.cjs","floating.ps1","tasks.ps1","window.ps1","README.md","notebook.ico","updater.cjs","apply-update.ps1","version.json","update-config.json","HandwritingNotebook.exe","HandwritingNotebookBackend.exe","Uninstall.exe"};
  internal static void RemoveFiles(string root) {
    root=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);
    if(root==Path.GetPathRoot(root).TrimEnd(Path.DirectorySeparatorChar)||!File.Exists(Path.Combine(root,"floating.ps1"))||!File.Exists(Path.Combine(root,"version.json")))throw new InvalidOperationException("无法确认软件安装目录，已取消卸载。");
    if((File.GetAttributes(root)&FileAttributes.ReparsePoint)!=0)throw new InvalidOperationException("不能卸载链接目录。");
    foreach(string name in Files){string file=Path.Combine(root,name);if(File.Exists(file)&&(File.GetAttributes(file)&FileAttributes.ReparsePoint)!=0)throw new InvalidOperationException("程序文件包含链接，已取消卸载。");}
    foreach(string name in Files){string file=Path.Combine(root,name);if(File.Exists(file))File.Delete(file);}
    if(Directory.GetFileSystemEntries(root).Length==0)Directory.Delete(root);
  }
  [STAThread] static void Main(string[] args) {
    Application.EnableVisualStyles();
    try {
      if(args.Length==0){string helper=Path.Combine(Path.GetTempPath(),"NotebookUninstall-"+Guid.NewGuid().ToString("N")+".exe");File.Copy(Application.ExecutablePath,helper);Process.Start(new ProcessStartInfo(helper,"--remove \""+AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\')+"\""){UseShellExecute=false});return;}
      if(args.Length!=2||args[0]!="--remove")throw new ArgumentException("卸载参数无效。");
      try{using(Mutex ball=Mutex.OpenExisting("Local\\HandwritingNotebookFloatingBall")){bool held=false;try{held=ball.WaitOne(0);}catch(AbandonedMutexException){held=true;}if(!held){MessageBox.Show("请先保存工程，右键浮动球选择退出笔记本，再运行卸载程序。","手写笔记本卸载");return;}ball.ReleaseMutex();}}catch(WaitHandleCannotBeOpenedException){}
      foreach(string name in new[]{"HandwritingNotebook","HandwritingNotebookBackend"})foreach(Process p in Process.GetProcessesByName(name)){using(p){string location;try{location=p.MainModule.FileName;}catch{throw new InvalidOperationException("无法确认程序是否已退出，请关闭笔记本后重试。");}if(string.Equals(Path.GetDirectoryName(location),Path.GetFullPath(args[1]).TrimEnd('\\'),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("请先退出笔记本，再卸载。");}}
      if(MessageBox.Show("卸载手写笔记本？\n\n将删除程序文件。工程文件、设置、自动备份及其他个人文件会保留。","手写笔记本卸载",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;
      RemoveFiles(args[1]);MessageBox.Show("卸载完成。工程、设置和自动备份已保留。","手写笔记本卸载");
    }catch(Exception ex){MessageBox.Show("卸载未完成："+ex.Message,"手写笔记本卸载",MessageBoxButtons.OK,MessageBoxIcon.Error);}
  }
}
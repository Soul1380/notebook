using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Drawing;
using System.Diagnostics;
using System.Threading;
using System.Management;
class Updater : Form {
  string root=AppDomain.CurrentDomain.BaseDirectory; Label status=new Label(); ProgressBar bar=new ProgressBar();
  static string[] allowed={"index.html","styles.css","app.js","preferences.js","colors.js","files.js","interaction.js","desktop.cjs","floating.ps1","tasks.ps1","window.ps1","README.md","notebook.ico","version.json","HandwritingNotebook.exe","HandwritingNotebookBackend.exe"};
  Updater(){Text="手写笔记本更新";StartPosition=FormStartPosition.CenterScreen;ClientSize=new Size(480,135);ControlBox=false;bar.SetBounds(22,22,435,22);status.SetBounds(22,59,435,48);Controls.Add(bar);Controls.Add(status);Shown+=(s,e)=>ThreadPool.QueueUserWorkItem(_=>Run());}
  void Step(int n,string text){BeginInvoke((Action)(()=>{bar.Value=Math.Max(0,Math.Min(100,n));status.Text=text;}));}
  static string Hex(byte[] b){return BitConverter.ToString(b).Replace("-","").ToLowerInvariant();}
  internal static bool BelongsToNotebook(string executable,string command,string installRoot){
    string folder=Path.GetFullPath(installRoot).TrimEnd(Path.DirectorySeparatorChar);
    if(!String.IsNullOrEmpty(executable)&&String.Equals(Path.GetDirectoryName(executable),folder,StringComparison.OrdinalIgnoreCase)&&(String.Equals(Path.GetFileName(executable),"HandwritingNotebook.exe",StringComparison.OrdinalIgnoreCase)||String.Equals(Path.GetFileName(executable),"HandwritingNotebookBackend.exe",StringComparison.OrdinalIgnoreCase)))return true;
    if(String.IsNullOrEmpty(command))return false;
    foreach(string relative in new[]{"floating.ps1","desktop.cjs",".browser-data"}){
      string target=Path.Combine(folder,relative);int index=command.IndexOf(target,StringComparison.OrdinalIgnoreCase);
      if(index>=0){int end=index+target.Length;if(end==command.Length||command[end]=='"'||Char.IsWhiteSpace(command[end]))return true;}
    }
    return false;
  }
  bool NotebookRunning(){
    using(var search=new ManagementObjectSearcher("SELECT ProcessId,Name,ExecutablePath,CommandLine FROM Win32_Process WHERE Name='HandwritingNotebook.exe' OR Name='HandwritingNotebookBackend.exe' OR Name='powershell.exe' OR Name='node.exe' OR Name='msedge.exe'"))
    using(var results=search.Get()){foreach(ManagementObject item in results){using(item){if(BelongsToNotebook(Convert.ToString(item["ExecutablePath"]),Convert.ToString(item["CommandLine"]),root))return true;}}}
    return false;
  }  void Run(){string cache=Path.Combine(root,".update-cache"),stage=Path.Combine(cache,"stage-"+Guid.NewGuid().ToString("N")),backup=Path.Combine(cache,"backup-"+Guid.NewGuid().ToString("N"));var installed=new List<string>();var existed=new HashSet<string>(StringComparer.OrdinalIgnoreCase);bool replacing=false;
    try{
      Step(2,"正在检查 GitHub 版本…");ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;Directory.CreateDirectory(cache);var json=new JavaScriptSerializer();Dictionary<string,object> release;
      using(var wc=new WebClient()){wc.Headers.Add("User-Agent","HandwritingNotebook-Updater");release=json.Deserialize<Dictionary<string,object>>(wc.DownloadString("https://api.github.com/repos/Soul1380/notebook/releases/latest"));}
      string tag=Convert.ToString(release["tag_name"]).TrimStart('v');Version latest,current;var local=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(root,"version.json")));if(!Version.TryParse(tag,out latest)||!Version.TryParse(Convert.ToString(local["version"]),out current)||latest.Revision>=0||current.Revision>=0)throw new Exception("版本号格式无效");if(latest<=current){BeginInvoke((Action)(()=>{MessageBox.Show(this,"已是最新版本。","软件更新");Close();}));return;}
      Dictionary<string,object> asset=null;foreach(object obj in (System.Collections.IEnumerable)release["assets"]){var a=(Dictionary<string,object>)obj;if(Convert.ToString(a["name"])=="HandwritingNotebook-update.zip")asset=a;}if(asset==null)throw new Exception("新版本未提供更新包");string digest=Convert.ToString(asset["digest"]),url=Convert.ToString(asset["browser_download_url"]);long size=Convert.ToInt64(asset["size"]);if(!System.Text.RegularExpressions.Regex.IsMatch(digest??"","^sha256:[0-9a-fA-F]{64}$")||size<=0||size>150*1024*1024||!url.StartsWith("https://github.com/Soul1380/notebook/releases/download/",StringComparison.Ordinal))throw new Exception("更新包信息无效");
      Step(8,"正在下载更新包…");string zipPath=Path.Combine(cache,"download-"+Guid.NewGuid().ToString("N")+".zip");using(var wc=new WebClient()){wc.Headers.Add("User-Agent","HandwritingNotebook-Updater");wc.DownloadFile(url,zipPath);}if(new FileInfo(zipPath).Length!=size)throw new Exception("下载大小不匹配");Step(25,"正在校验更新包…");using(var f=File.OpenRead(zipPath))using(var sha=SHA256.Create()){if(Hex(sha.ComputeHash(f))!=digest.Substring(7).ToLowerInvariant())throw new Exception("更新包校验失败");}
      Directory.CreateDirectory(stage);Directory.CreateDirectory(backup);var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);long expanded=0;using(var zip=ZipFile.OpenRead(zipPath)){foreach(var entry in zip.Entries){if(Array.IndexOf(allowed,entry.FullName)<0||!seen.Add(entry.FullName))throw new Exception("更新包包含不支持的文件");expanded+=entry.Length;if(expanded>250*1024*1024)throw new Exception("更新包过大");entry.ExtractToFile(Path.Combine(stage,entry.FullName));}}foreach(string file in allowed)if(!seen.Contains(file))throw new Exception("更新包缺少文件："+file);var packaged=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(stage,"version.json")));if(Convert.ToString(packaged["version"])!=tag)throw new Exception("更新包版本不匹配");
      Step(35,"正在关闭笔记本…");string session=Path.Combine(root,".notebook-session.json");if(File.Exists(session)){var state=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(session));string key=Convert.ToString(state["key"]);if(!System.Text.RegularExpressions.Regex.IsMatch(key??"","^[0-9a-f]{64}$"))throw new Exception("无法确认笔记本进程");File.WriteAllText(Path.Combine(root,".update-exit-request"),key);Thread.Sleep(700);using(var wc=new WebClient()){wc.Headers.Add("X-Notebook-Shutdown",key);wc.UploadString("http://127.0.0.1:17683/shutdown","POST","");}}
      var watch=Stopwatch.StartNew();int clearChecks=0;
      while(clearChecks<4){if(NotebookRunning()){clearChecks=0;Step(36,"正在等待浮动球、后台和画板窗口完全退出…");}else clearChecks++;if(watch.ElapsedMilliseconds>30000)throw new Exception("程序仍在运行，已取消覆盖。请退出笔记本后重试。");Thread.Sleep(250);}
      foreach(string name in allowed){string file=Path.Combine(root,name);if(File.Exists(file))using(var probe=new FileStream(file,FileMode.Open,FileAccess.ReadWrite,FileShare.None)){} }
      replacing=true;int done=0;foreach(string name in allowed){if(NotebookRunning())throw new Exception("检测到笔记本重新启动，停止覆盖并恢复旧文件");Step(40+(int)(50.0*done/allowed.Length),"正在安装："+name);string dest=Path.Combine(root,name);if(File.Exists(dest)){File.Copy(dest,Path.Combine(backup,name));existed.Add(name);}installed.Add(name);File.Copy(Path.Combine(stage,name),dest,true);done++;}replacing=false;Step(100,"更新完成，正在重启…");Process.Start(Path.Combine(root,"HandwritingNotebook.exe"));BeginInvoke((Action)(()=>Close()));
    }catch(Exception ex){string rollbackError="";if(replacing)foreach(string name in installed){try{string dest=Path.Combine(root,name);if(existed.Contains(name))File.Copy(Path.Combine(backup,name),dest,true);else if(File.Exists(dest))File.Delete(dest);}catch(Exception restore){rollbackError+="\n"+name+": "+restore.Message;}}try{File.AppendAllText(Path.Combine(cache,"updater-error.log"),DateTime.Now+" "+ex+rollbackError+Environment.NewLine);}catch{}BeginInvoke((Action)(()=>{MessageBox.Show(this,"更新失败："+ex.Message+(rollbackError.Length>0?"\n部分文件恢复失败，请查看日志。":"\n原程序文件已保留或恢复。"),"软件更新");Close();}));}
  }
  [STAThread] static void Main(){Application.EnableVisualStyles();Application.Run(new Updater());}
}
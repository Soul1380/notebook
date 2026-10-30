using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Drawing;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
[assembly: AssemblyTitle("Handwriting Notebook Setup")]
[assembly: AssemblyDescription("Handwriting Notebook installer")]
[assembly: AssemblyProduct("Handwriting Notebook")]
[assembly: AssemblyVersion("1.0.0.0")]
internal sealed class SetupForm : Form {
  readonly TextBox path = new TextBox(); readonly Button browse = new Button(); readonly Button install = new Button();
  readonly Button close = new Button(); readonly ProgressBar progress = new ProgressBar(); readonly Label status = new Label(); readonly CheckBox launch = new CheckBox();
  bool busy = false, installed = false;
  public SetupForm() {
    Text="手写笔记本安装程序";ClientSize=new Size(620,590);MinimumSize=new Size(636,629);StartPosition=FormStartPosition.CenterScreen;BackColor=Color.FromArgb(250,248,242);Font=new Font("Microsoft YaHei UI",9F);
    var heading=new Label {Text="✎  手写笔记本",Font=new Font("Microsoft YaHei UI",20F,FontStyle.Bold),ForeColor=Color.FromArgb(38,63,53),AutoSize=true,Location=new Point(28,24)};Controls.Add(heading);
    var subtitle=new Label {Text="HANDWRITING NOTEBOOK  ·  WINDOWS 安装程序",AutoSize=true,ForeColor=Color.FromArgb(123,138,125),Location=new Point(31,71)};Controls.Add(subtitle);
    var pathTitle=new Label {Text="安装位置",AutoSize=true,Font=new Font(Font,FontStyle.Bold),Location=new Point(31,113)};Controls.Add(pathTitle);
    path.SetBounds(32,140,450,28);path.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","HandwritingNotebook");path.Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right;Controls.Add(path);
    browse.Text="浏览…";browse.SetBounds(491,138,96,30);browse.Anchor=AnchorStyles.Top|AnchorStyles.Right;browse.Click+=(s,e)=>{using(var d=new FolderBrowserDialog()){d.Description="选择安装文件夹";if(Directory.Exists(path.Text))d.SelectedPath=path.Text;if(d.ShowDialog(this)==DialogResult.OK)path.Text=d.SelectedPath;}};Controls.Add(browse);
    var noticeTitle=new Label {Text="使用须知",AutoSize=true,Font=new Font(Font,FontStyle.Bold),Location=new Point(31,190)};Controls.Add(noticeTitle);
    var notice=new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,BorderStyle=BorderStyle.FixedSingle,BackColor=Color.White,Text="• 支持 Windows 10 / 11 64 位，需要已安装 Microsoft Edge。\r\n\r\n• 安装后运行文件夹中的 HandwritingNotebook.exe；先显示浮动球，点击浮动球打开画板。\r\n\r\n• 右键浮动球可设置皮肤或退出笔记本。\r\n\r\n• 每次打开默认是空白画布；请使用“保存工程”保存可再次编辑的 .notebook 文件。也可以从文件标签恢复上次自动备份。\r\n\r\n• 安装版与先前启动的旧版使用各自的数据。请先在旧版保存工程，然后在安装版中打开该工程。\r\n\r\n• 工程保存目录可在笔记本的首选项 → UI 界面设置中选择。安装目录应选择有写入权限的位置。"};notice.SetBounds(32,218,555,213);notice.Anchor=AnchorStyles.Top|AnchorStyles.Bottom|AnchorStyles.Left|AnchorStyles.Right;Controls.Add(notice);
    launch.Text="安装完成后启动";launch.Checked=true;launch.AutoSize=true;launch.Location=new Point(32,445);launch.Anchor=AnchorStyles.Bottom|AnchorStyles.Left;Controls.Add(launch);
    progress.SetBounds(32,480,555,8);progress.Anchor=AnchorStyles.Bottom|AnchorStyles.Left|AnchorStyles.Right;Controls.Add(progress);
    status.SetBounds(32,492,555,20);status.ForeColor=Color.FromArgb(100,120,105);status.Text="准备就绪";status.Anchor=AnchorStyles.Bottom|AnchorStyles.Left|AnchorStyles.Right;Controls.Add(status);
    install.Text="安装";install.SetBounds(385,535,98,34);install.Anchor=AnchorStyles.Bottom|AnchorStyles.Right;install.BackColor=Color.FromArgb(38,63,53);install.ForeColor=Color.White;install.FlatStyle=FlatStyle.Flat;install.Click+=InstallClick;Controls.Add(install);
    close.Text="取消";close.SetBounds(492,535,95,34);close.Anchor=AnchorStyles.Bottom|AnchorStyles.Right;close.Click+=(s,e)=>{if(!busy)Close();};Controls.Add(close);FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};
  }
  void InstallClick(object sender,EventArgs e) {
    if(installed){Close();return;}string target;
    try {target=Path.GetFullPath(path.Text.Trim());if(string.IsNullOrWhiteSpace(path.Text)||target==Path.GetPathRoot(target))throw new ArgumentException("请选择普通文件夹。");}
    catch(Exception ex){MessageBox.Show(this,"安装位置无效："+ex.Message,"手写笔记本",MessageBoxButtons.OK,MessageBoxIcon.Warning);return;}
    if(Process.GetProcessesByName("HandwritingNotebook").Length>0||Process.GetProcessesByName("HandwritingNotebookBackend").Length>0){MessageBox.Show(this,"请先退出正在运行的手写笔记本，再继续安装。","手写笔记本",MessageBoxButtons.OK,MessageBoxIcon.Information);return;}
    bool existingApp=File.Exists(Path.Combine(target,"HandwritingNotebook.exe"));
    try { if(existingApp){if(MessageBox.Show(this,"该文件夹已有笔记本程序。更新会替换程序文件，保留现有数据。是否继续？","手写笔记本",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;}else if(Directory.Exists(target)&&Directory.GetFileSystemEntries(target).Length>0){if(MessageBox.Show(this,"所选文件夹不是空文件夹。安装会覆盖其中同名的程序文件，请确认安装位置。是否继续？","手写笔记本",MessageBoxButtons.YesNo,MessageBoxIcon.Warning)!=DialogResult.Yes)return;} } catch(Exception ex){MessageBox.Show(this,"无法检查安装文件夹："+ex.Message,"手写笔记本",MessageBoxButtons.OK,MessageBoxIcon.Warning);return;}
    busy=true;install.Enabled=false;browse.Enabled=false;path.Enabled=false;launch.Enabled=false;close.Enabled=false;status.Text="正在安装，请稍候…";bool start=launch.Checked;
    ThreadPool.QueueUserWorkItem(_=>{try{Extract(target,percent=>BeginInvoke((Action)(()=>{progress.Value=Math.Min(100,percent);status.Text="正在安装… "+percent+"%";})));BeginInvoke((Action)(()=>{busy=false;installed=true;status.Text="安装完成："+target;progress.Value=100;install.Enabled=true;install.Text="完成";close.Enabled=true;close.Text="关闭";if(start){try{Process.Start(Path.Combine(target,"HandwritingNotebook.exe"));}catch(Exception ex){MessageBox.Show(this,"已安装，但启动失败："+ex.Message);}}}));}catch(Exception ex){BeginInvoke((Action)(()=>{busy=false;install.Enabled=true;browse.Enabled=true;path.Enabled=true;launch.Enabled=true;close.Enabled=true;status.Text="安装失败";MessageBox.Show(this,"安装失败："+ex.Message,"手写笔记本",MessageBoxButtons.OK,MessageBoxIcon.Error);}));}});
  }
  internal static void Extract(string target,Action<int> report) {
    Directory.CreateDirectory(target);Directory.CreateDirectory(Path.Combine(target,"plugins"));
    string template=Path.Combine(target,"plugins","starter-template");Directory.CreateDirectory(template);
    foreach(string item in new[]{"StarterManifest|manifest.json","StarterReadme|README.md"}){string[] parts=item.Split('|');string dest=Path.Combine(template,parts[1]);if(!File.Exists(dest))using(var input=Assembly.GetExecutingAssembly().GetManifestResourceStream(parts[0])){if(input==null)throw new InvalidOperationException("插件样板资源缺失");using(var output=File.Create(dest))input.CopyTo(output);}}string pluginHelp=Path.Combine(target,"plugins","README.txt");if(!File.Exists(pluginHelp))File.WriteAllText(pluginHelp,"每个插件放入独立子文件夹，并提供 manifest.json。可选 icon 字段指定同目录 PNG、JPG、WebP 或 GIF 图标，不超过 512 KB。未提供时显示默认扩展图标。");string root=Path.GetFullPath(target).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
    using(var payload=Assembly.GetExecutingAssembly().GetManifestResourceStream("NotebookPayload.zip")) {
      if(payload==null)throw new InvalidOperationException("安装资源缺失。");
      using(var zip=new ZipArchive(payload,ZipArchiveMode.Read)) {long total=0,done=0;int lastPercent=-1;foreach(var entry in zip.Entries)total+=entry.Length;foreach(var entry in zip.Entries){string output=Path.GetFullPath(Path.Combine(root,entry.FullName.Replace('/',Path.DirectorySeparatorChar)));if(!output.StartsWith(root,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("安装资源路径无效。");if(entry.FullName.EndsWith("/")){Directory.CreateDirectory(output);continue;}Directory.CreateDirectory(Path.GetDirectoryName(output));using(var input=entry.Open())using(var dest=new FileStream(output,FileMode.Create,FileAccess.Write,FileShare.None)){byte[] buffer=new byte[131072];int count;while((count=input.Read(buffer,0,buffer.Length))>0){dest.Write(buffer,0,count);done+=count;int percent=total==0?100:(int)(done*100/total);if(report!=null&&percent!=lastPercent){lastPercent=percent;report(percent);}}}}}
    }
  }
}
internal static class Program { [STAThread] static void Main(){Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new SetupForm());} }

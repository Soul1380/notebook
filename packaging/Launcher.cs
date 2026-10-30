using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
using System.Drawing;
using System.Reflection;
[assembly: AssemblyTitle("Handwriting Notebook")]
[assembly: AssemblyDescription("Handwriting Notebook floating launcher")]
[assembly: AssemblyProduct("Handwriting Notebook")]
[assembly: AssemblyVersion("1.0.0.0")]
internal static class Launcher {
  static string root=AppDomain.CurrentDomain.BaseDirectory;
  static string WriteLog(string message){try{string dir=Path.Combine(root,"crash-logs");Directory.CreateDirectory(dir);string file=Path.Combine(dir,"crash-"+DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+".txt");File.WriteAllText(file,DateTime.Now.ToString("O")+Environment.NewLine+message);return file;}catch{return null;}}
  static bool ShowCrash(string log){
    using(var dialog=new Form()){
      dialog.Text="手写笔记本发生错误";dialog.StartPosition=FormStartPosition.CenterScreen;dialog.ClientSize=new Size(540,190);dialog.FormBorderStyle=FormBorderStyle.FixedDialog;dialog.MaximizeBox=false;dialog.MinimizeBox=false;
      var title=new Label{Text="程序意外退出。可以重新启动或退出。",AutoSize=true,Location=new Point(20,18)};dialog.Controls.Add(title);
      var path=new TextBox{ReadOnly=true,Text=log??"无法写入日志，请检查安装目录权限",Location=new Point(20,52),Width=495};dialog.Controls.Add(path);
      var open=new Button{Text="打开报错文件",Location=new Point(20,98),Width=110,Enabled=log!=null};open.Click+=(s,e)=>{try{Process.Start("explorer.exe","/select,\""+log+"\"");}catch{MessageBox.Show("无法打开文件位置。");}};dialog.Controls.Add(open);
      var restart=new Button{Text="重新启动",Location=new Point(286,98),Width=110,DialogResult=DialogResult.Retry};dialog.Controls.Add(restart);
      var quit=new Button{Text="退出",Location=new Point(405,98),Width=110,DialogResult=DialogResult.Cancel};dialog.Controls.Add(quit);dialog.CancelButton=quit;
      return dialog.ShowDialog()==DialogResult.Retry;
    }
  }
  [STAThread] static void Main(){
    Application.EnableVisualStyles();string script=Path.Combine(root,"floating.ps1");
    while(true){try{
      if(!File.Exists(script))throw new FileNotFoundException("找不到浮动球脚本",script);
      var start=new ProcessStartInfo(Path.Combine(Environment.SystemDirectory,@"WindowsPowerShell\v1.0\powershell.exe"),"-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \""+script+"\"");start.WorkingDirectory=root;start.UseShellExecute=false;start.CreateNoWindow=true;start.RedirectStandardError=true;
      using(var process=Process.Start(start)){if(process==null)throw new InvalidOperationException("无法启动浮动球");string errors=process.StandardError.ReadToEnd();process.WaitForExit();if(process.ExitCode==0)return;if(!ShowCrash(WriteLog("浮动球退出代码: "+process.ExitCode+Environment.NewLine+errors)))return;}
    }catch(Exception ex){if(!ShowCrash(WriteLog(ex.ToString())))return;}}
  }
}
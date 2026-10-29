using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
using System.Reflection;
[assembly: AssemblyTitle("Handwriting Notebook")]
[assembly: AssemblyDescription("Handwriting Notebook floating launcher")]
[assembly: AssemblyProduct("Handwriting Notebook")]
[assembly: AssemblyVersion("1.0.0.0")]
internal static class Launcher {
  [STAThread] static void Main() {
    string root=AppDomain.CurrentDomain.BaseDirectory;
    string script=Path.Combine(root,"floating.ps1");
    if (!File.Exists(script)) {MessageBox.Show("找不到笔记本程序文件，请重新安装。", "手写笔记本", MessageBoxButtons.OK, MessageBoxIcon.Error);return;}
    try {
      var start=new ProcessStartInfo();start.FileName=Path.Combine(Environment.SystemDirectory,@"WindowsPowerShell\v1.0\powershell.exe");
      start.Arguments="-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \""+script+"\"";
      start.WorkingDirectory=root;start.UseShellExecute=false;start.CreateNoWindow=true;start.WindowStyle=ProcessWindowStyle.Hidden;
      using (var process=Process.Start(start)) {if(process!=null)process.WaitForExit();}
    } catch(Exception ex){MessageBox.Show("无法启动手写笔记本：\n"+ex.Message,"手写笔记本",MessageBoxButtons.OK,MessageBoxIcon.Error);}
  }
}

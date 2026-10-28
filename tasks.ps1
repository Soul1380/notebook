param([ValidateSet('list','activate')][string]$Action='list', [string]$Id='')
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.dll @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
public class TaskWindow {
 public string id; public string title; public string icon;
}
public static class NotebookTasks {
 delegate bool EnumProc(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f,IntPtr p);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h,int n);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a,uint b,bool attach);
 [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h,uint command);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h,int index);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint id);
 [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,IntPtr l,uint flags,uint timeout,out IntPtr result);
 [DllImport("user32.dll",EntryPoint="GetClassLongPtrW")] static extern IntPtr GetClassLong64(IntPtr h,int index);
 [DllImport("user32.dll",EntryPoint="GetClassLongW")] static extern IntPtr GetClassLong32(IntPtr h,int index);
 [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h,int attr,out int value,int size);
 static bool Eligible(IntPtr h,out string title){title="";if(!IsWindowVisible(h)||GetWindow(h,4)!=IntPtr.Zero||(GetWindowLong(h,-20)&0x80)!=0)return false;int cloaked=0;try{DwmGetWindowAttribute(h,14,out cloaked,4);}catch{} if(cloaked!=0)return false;var t=new StringBuilder(512);GetWindowText(h,t,t.Capacity);title=t.ToString().Trim();return title.Length>0&&!title.StartsWith("Notebook - ")&&title!="Program Manager";}
 static string IconData(IntPtr h){try{IntPtr icon;SendMessageTimeout(h,0x7f,new IntPtr(2),IntPtr.Zero,2,100,out icon);if(icon==IntPtr.Zero)SendMessageTimeout(h,0x7f,IntPtr.Zero,IntPtr.Zero,2,100,out icon);if(icon==IntPtr.Zero)icon=IntPtr.Size==8?GetClassLong64(h,-34):GetClassLong32(h,-34);using(var bmp=icon!=IntPtr.Zero?Icon.FromHandle(icon).ToBitmap():ProcessIcon(h)){if(bmp==null)return null;using(var small=new Bitmap(bmp,new Size(32,32)))using(var stream=new MemoryStream()){small.Save(stream,ImageFormat.Png);return "data:image/png;base64,"+Convert.ToBase64String(stream.ToArray());}}}catch{return null;}}
 static Bitmap ProcessIcon(IntPtr h){uint id;GetWindowThreadProcessId(h,out id);using(var process=Process.GetProcessById((int)id)){using(var icon=Icon.ExtractAssociatedIcon(process.MainModule.FileName)){return icon==null?null:icon.ToBitmap();}}}
 public static TaskWindow[] List(){var items=new List<TaskWindow>();EnumWindows((h,p)=>{string title;if(Eligible(h,out title))items.Add(new TaskWindow{id=h.ToInt64().ToString(),title=title,icon=IconData(h)});return true;},IntPtr.Zero);return items.ToArray();}
 public static bool Activate(long id){var h=new IntPtr(id);string title;if(!Eligible(h,out title))return false;uint current=GetCurrentThreadId(),owner;uint foreground=GetWindowThreadProcessId(GetForegroundWindow(),out owner);bool joined=foreground!=0&&foreground!=current&&AttachThreadInput(current,foreground,true);try{if(IsIconic(h))ShowWindow(h,9);BringWindowToTop(h);return SetForegroundWindow(h);}finally{if(joined)AttachThreadInput(current,foreground,false);}}
}
"@
if($Action -eq 'list'){ $result=@([NotebookTasks]::List()); ConvertTo-Json -InputObject $result -Depth 4 -Compress }
else { $number=0L; if(-not [long]::TryParse($Id,[ref]$number)){exit 1};if(-not [NotebookTasks]::Activate($number)){exit 1};'{}' }


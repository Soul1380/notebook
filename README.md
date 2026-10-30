# 手写笔记本

Windows 手写画板，支持笔迹、图片、文本框、可定位的注解框和工程文件。

## 安装与启动

从本仓库的 Releases 下载 Windows 安装程序，选择一个有写入权限的安装位置。安装版需要 64 位 Windows 10/11 和 Microsoft Edge；运行安装目录中的 `HandwritingNotebook.exe`，再点击浮动球打开画板。右键浮动球可以更换皮肤、打开软件所在目录或退出。

普通启动时画布为空白。需要继续编辑时，请在“文件”标签中打开 `.notebook` 工程；也可选择“恢复上次画布”恢复本机自动备份。开始新编辑可能覆盖自动备份，建议先保存工程。

旧版和新安装目录各自保存浏览器数据。迁移时请在旧版导出 `.notebook` 工程，再在新版中打开。

## 画布和工具

- 左键拖动书写；在空白处长按片刻再拖动，可移动画布。鼠标滚轮以指针为中心缩放。
- 选择画笔、局部擦除、图形、图片或文本框；选中对象后按 Delete 删除，Ctrl+Z 撤回。图形拖动时按住 Shift，可从中心展开。
- Windows 截图后激活窗口并按 Ctrl+V 可粘贴图片。文本框支持宋体和自动换行，双击可编辑。
- 创建注解框后，双击上方标签重命名；通过“注解”标签搜索并定位。按住 Ctrl 拖动框内部，可移动注解框、框内笔迹和完整位于框内的图片与文本框；跨越边界的笔迹仅移动框内部分。
- 在画布上按住右键并向目标方向拖动，可使用轮盘选择常用工具。也可以右键单击后点击工具。
- PNG 导出按内容范围裁切，四周各预留约 0.1 厘米（按 96 DPI 换算）。工程文件保留可编辑对象。

## 设置与快捷键

“窗口 → 首选项”中可按类别设置快捷键，也可调整 UI 比例、画布点阵、界面颜色和提示显示。左下角半透明提示框跟随当前工具标签，只显示部分已设置的快捷键。

首选项还可选择工程文件保存目录。Shift+F 打开快捷查询，可在 Chrome 中搜索，或复制问题并打开 ChatGPT；ChatGPT 中的聊天需要手动选择。

## 构建

`packaging/Build.ps1` 在 Windows 上使用系统 .NET Framework 编译器，需指定 Node.js 可执行文件、临时目录、安装程序输出路径。开发用的 `index.html` 可以直接在浏览器打开；窗口切换仅在安装版中可用。

## 卸载

安装目录内运行 Uninstall.exe，先保存工程并通过浮动球右键菜单退出软件。卸载仅删除程序文件，保留工程、设置、自动备份和其他个人文件。

浮动球拖到距屏幕左右边缘 100 像素以内并松开，会自动吸附；鼠标离开后隐藏到边缘，移回时展开。

## 插件使用手册（1.0.5）

在“首选项 → 插件”点击“打开插件目录”。为每个插件创建独立子文件夹，在其中放置 UTF-8 编码的 manifest.json；点击“刷新列表”，再用开关启用。插件文件和启用状态会保留在本机。此版本采用声明式插件，不执行插件 JavaScript 或任意系统命令。

每个 manifest.json 都必须提供 name（名称）、version（版本）、author（作者）、description（简介）、type（类型）和 config（配置）。插件目录名即唯一 ID，只能包含英文字母、数字、点、横线或下划线。以下五类可以分别创建：

### 界面 ui

```json
{"name":"森林界面","version":"1.0.0","author":"示例","description":"调整工具栏颜色","type":"ui","config":{"toolbarBackground":"#EAF2E8","activeTab":"#BBDDC1","buttonBackground":"#D7E8D5","buttonText":"#294C3A"}}
```
颜色为六位十六进制值；变量分别是工具栏背景、活动选项卡背景、插件工具按钮背景和文字颜色。

### 工具 tool

```json
{"name":"快捷工具","version":"1.0.0","author":"示例","description":"添加复位视图按钮","type":"tool","config":{"actions":[{"label":"复位视图","command":"zoomReset"},{"label":"放大","command":"zoomIn"}]}}
```
支持的 command：pen、eraser、select、text、check、undo、zoomIn、zoomOut、zoomReset。工具按钮出现在绘制工具栏。此版本提供已有工具的组合入口，不运行自定义工具代码。

### 运行优化 optimization

```json
{"name":"减少动画","version":"1.0.0","author":"示例","description":"减少界面过渡动画","type":"optimization","config":{"reduceMotion":true}}
```
此类型目前提供减少界面动画，并不承诺提升画布性能或允许执行后台程序。

### 字体 font

```json
{"name":"我的字体","version":"1.0.0","author":"示例","description":"为文本框提供字体","type":"font","config":{"file":"myfont.woff2"}}
```
将字体文件放在 manifest.json 同一文件夹，支持 woff、woff2、ttf、otf，最大 10 MB。启用后在文本字体选择框中选择。其他电脑需要安装同 ID 插件才能显示此字体。

### 语言包 language

```json
{"name":"English","version":"1.0.0","author":"示例","description":"常用工具英文名称","type":"language","config":{"labels":{"pen":"Pen","eraser":"Eraser","select":"Select","text":"Text","check":"Checklist","undo":"Undo","save":"Save PNG","preferences":"Settings","newProject":"New","openProject":"Open"}}}
```
可翻译的键为以上示例中的键。缺失的翻译沿用原文；用户笔记内容不会翻译。多个同类插件同时启用时，后加载的设置覆盖同名项。禁用插件立即撤销它的界面效果；插件字体在禁用时将回退为系统字体。

## 报表提醒接口

在“首选项 → 小球提醒”开启或关闭提醒。浮动球运行时，每两秒检查安装目录下的 `.report-notice.json`；关闭提醒时保留等待中的通知，开启后显示。生成报表的外部程序可先把 UTF-8 JSON 写到同目录临时文件，再原子重命名为 `.report-notice.json`，内容示例：

```json
{"title":"每日信息报表","path":"C:\\Reports\\daily.pdf"}
```

浮动球弹出对话框显示标题和报表位置，用户自行打开文件。通知只保存一条；下一条应在上一条被读取后再写入，否则会覆盖。软件不负责定时收集信息，也不创建报表；浮动球必须正在运行才能显示提醒。

## 界面文字选择标准

选项卡、工具栏、品牌标识、进程栏、画布状态和提示属于操作界面，默认不可作为网页文本选中；未来新增的选项卡和控件继承此规则。文字仍使用普通可访问的 HTML 和按钮，不转换为图片。文本框、搜索框、数字输入框及可编辑内容保留文字选择和 Ctrl+A，方便编辑。画布或普通控件获得焦点时，Ctrl+A 不触发浏览器整页选择；用户自定义了 Ctrl+A 快捷键时继续执行该快捷键。进程图标不允许拖拽。新增输入组件应确保仍支持选择、复制、键盘操作与无障碍访问。

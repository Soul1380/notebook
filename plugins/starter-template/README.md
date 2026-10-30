# 初始插件样板

这是一个没有任何功能的插件，默认关闭，开关操作不会修改笔记或界面。

复制 starter-template 文件夹并为副本取一个新的英文目录名，再修改 manifest.json 的名称、版本、作者和简介。
需要具体功能时，将 type 改为 ui、tool、optimization、font 或 language，并按软件 README.md 中的插件手册填写 config。

图标：默认不提供 icon 字段，使用软件的默认扩展图标。可添加 "icon": "icon.png"，并把图标图片放在本插件文件夹中。

仅修改版本号或开启本样板不会自动增加功能。请在完成修改后到首选项 → 插件点击刷新。
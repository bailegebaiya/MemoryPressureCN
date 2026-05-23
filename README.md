# 内存压力仪

一个极简 macOS 菜单栏小工具，只显示内存状态，中文界面。

## 功能

- 菜单栏显示已用内存百分比
- 状态栏直接用小图标显示百分比，不占用过多菜单栏空间
- 面板重点显示当前内存占用最高的程序
- 面板补充显示已用内存、空闲+缓存、压缩内存、交换空间和系统压力
- 每 2 秒自动刷新
- 只读监控，不做内存清理

## 构建

```bash
swift build -c release
```

## 打包成 App

```bash
chmod +x Scripts/package-app.sh
Scripts/package-app.sh
```

生成的应用在：

```text
build/内存压力仪.app
```

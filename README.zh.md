# Ethernet Status Lite

[English](README.md) | 中文

> Ethernet Status Lite 是一个启发/重构自 [Ethernet Status](https://github.com/johanohly/ethernet-status) 26.02.18 版本的 macOS 菜单栏 App。非常感谢 [johanohly](https://github.com/johanohly/) 的开源贡献！

Ethernet Status Lite 是一个轻量的 macOS 菜单栏 App，旨在替换原生的 Wi-Fi 菜单栏图标，基于 Ethernet Status。可以实时指示您的网络状态—— Wi-Fi（普通/热点）、以太网（有线网）、连接关闭/异常，并提供多种呼出原生 Wi-Fi 切换界面的选项。

<table style="width: 100%; border-collapse: collapse; text-align: center; vertical-align: middle;">
    <thead>
        <tr style="background-color: #f2f2f2;">
            <th style="border: 1px solid #ccc; padding: 10px; width: 30%;">程序设置页</th>
            <th colspan="2" style="border: 1px solid #ccc; padding: 10px; width: 70%;">网络状态</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan="5" style="border: 1px solid #ccc; padding: 10px; background-color: #fafafa;">
                <img width=100% alt="app main view" src="https://github.com/user-attachments/assets/908d3b05-5152-49c0-9afb-e30cdcfdad17" />
            </td>
            <td style="border: 1px solid #ccc; padding: 10px; width: 100%;">以太网</td>
            <td style="border: 1px solid #ccc; padding: 10px; width: 25%;">
              <img width=100% src="https://github.com/user-attachments/assets/3fe0126f-dfe9-4376-ac80-706bdd61df4e" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">Wi-Fi</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/a2b9a3ff-5000-4e66-92d4-702d4a512418" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">热点</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/ed1af49a-433c-421e-af8b-c4609fc12fb9" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">网络关闭</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/7c73fea1-bcea-4c1a-9c55-1aacc23234ee" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">网络异常/其他</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/0ca10050-aacd-475d-9e8d-ee9c829bc841" />
            </td>
        </tr>
    </tbody>
</table>

推荐 [Ice](https://github.com/jordanbaird/Ice)、iBar、Bartender 等菜单栏管理工具，以隐藏原生 Wi-Fi 图标，

> Ethernet Status Lite 的开发初衷是：近代 macOS 的原生菜单栏网络图标竟然只能显示无线网状态，在使用有线网时不管不顾，这谁受得了？！因此我们希望能做一个功能类似 Windows 菜单栏网络图标、能够替代原生菜单栏 Wi-Fi 图标的 App。

## 功能

> 相比 Ethernet Status 26.02.18，我们去除了内置的网络面板、流量监控与网络强度显示功能，采用呼出原生 Wi-Fi 面板的方式（以方便无线使用时切换连接）

- 自适应菜单栏图标（以太网（有线网）、Wi-Fi（普通/热点）、连接关闭/异常）
- 三种呼出原生 Wi-Fi 菜单的方式（推荐：控制中心(1)方式）
- 多语言与客制化

## 安装

在 [Releases](../../releases/latest) 页面下载 `EthernetStatusLite.dmg`，拖动程序到**应用程序**文件夹。

若出现安全警告，请在终端中移除隔离属性：

```sh
xattr -d com.apple.quarantine "/Applications/Ethernet Status Lite.app"
```

App 仅在菜单栏运行（无 Dock 图标）。

## 从源码构建

需要 Xcode 命令行工具。

```sh
./build.sh
open ".build/Ethernet Status Lite.app"
```

## 许可证

GPL-3.0，与 Ethernet Status 一致。

## 致谢

- [johanohly/ethernet-status](https://github.com/johanohly/ethernet-status) — 原项目
- [Ice](https://github.com/jordanbaird/Ice) — 菜单栏管理工具

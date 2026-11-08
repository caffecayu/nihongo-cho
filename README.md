<div align="center">

# 毎日にほんご帳

每天一点的日语单词 + 口语练习本

</div>

## 下载

| 平台 | 获取方式 | 状态 |
|---|---|---|
| **macOS** | [下载 Mac 版](https://github.com/caffecayu/nihongo-cho/releases/latest/download/Nihongo-Cho-mac.zip)（Apple 芯片 / Intel 通用） | ✅ 可用 |
| **Windows** | [下载 Windows 安装包](https://github.com/caffecayu/nihongo-cho/releases/latest/download/Nihongo-Cho-windows-setup.exe)（Windows 10 / 11） | ✅ 可用 |
| **Android** | [下载 APK](https://github.com/caffecayu/nihongo-cho/releases/latest/download/Nihongo-Cho-android.apk) | ✅ 可用 |
| **iPhone / iPad** | 用 Safari 打开 [网页版](https://caffecayu.github.io/nihongo-cho/)，点「分享 › 添加到主屏幕」 | ✅ 可用（不含口语练习） |
| iOS / iPadOS 原生版 | 正在开发 | 🚧 |

网页版：<https://caffecayu.github.io/nihongo-cho/>

### 第一次打开

- **Mac**：解压后拖进「应用程序」。第一次打开如果提示无法验证开发者，到 **系统设置 › 隐私与安全性** 点「仍要打开」。
- **Windows**：运行安装包时如果出现「Windows 已保护你的电脑」，点「更多信息 › 仍要运行」。
- **Android**：下载 APK 后点开安装，按提示允许「安装未知应用」。

## 功能

- **单词**：每组 5 个词，先集中学习，再测「选意思 → 假名读音 → 汉字书写」，最后打勾清单。按间隔重复安排复习，当天答对的词不再出现。
- **学习进度**：默认从 Unit1 第1回开始，在速度表右上角的齿轮里可以调整当前单元和每天的任务量。
- **手写汉字**：Mac 上可以把整块触控板当书写板。
- **复习模式**：按单元列出全部单词，选择题型后自测。
- **任务日志**：日历上记录考试和作业，显示倒计时。
- **口语练习**：10 段「先生と面談する」会话，老师（若叶睦的声音）先说，你用日语回答，检查目标句型；还有随机抽问的模拟面谈。
- **场景短语**：便利店、餐厅、学校、问路等常用表达。
- **皮肤**：10 个主题色、自定义背景图和毛玻璃面板。

学习记录只保存在你自己的设备上，可以在「我的」里导出备份。

## 自己构建

```bash
python3 tools/build.py          # 由 src/app.html + data/share.json 生成 docs/
zsh mac/make_share_app.sh       # 生成 Mac 版到 build/mac/
```

Windows 安装包和 Android APK 由 GitHub Actions（.github/workflows/build.yml）在推送版本标签时自动构建。

## 致谢

- 手写识别：[KanjiCanvas](https://github.com/asdfjkl/kanjicanvas)（MIT）
- 日语发音：若叶睦 GPT-SoVITS 社区音色（预先录好的音频）
- Windows / Android 打包：Tauri、Capacitor

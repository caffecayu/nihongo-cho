<div align="center">

# 毎日にほんご帳

每天一点的日语单词 + 口语练习本

</div>

## 下载

| 平台 | 获取方式 | 状态 |
|---|---|---|
| **macOS** | [下载 Mac 版（Apple 芯片 / Intel 通用）](https://github.com/caffecayu/nihongo-cho/releases/latest/download/Nihongo-Cho-mac.zip) | ✅ 可用 |
| **Windows** | [打开网页版](https://caffecayu.github.io/nihongo-cho/)，用 Edge 或 Chrome 选「安装此站点为应用」 | ✅ 可用 |
| Android | 正在开发 | 🚧 |
| iOS | 正在开发 | 🚧 |
| iPadOS | 正在开发 | 🚧 |

网页版地址：<https://caffecayu.github.io/nihongo-cho/>（任何浏览器都能直接用）

### Mac 版第一次打开

Mac 版没有付费签名，第一次打开时系统会拦一下：

1. 解压后把「毎日にほんご帳」拖进「应用程序」。
2. 双击打开，如果提示无法验证开发者，点「完成」。
3. 打开 **系统设置 › 隐私与安全性**，在下方找到「毎日にほんご帳」，点「仍要打开」。

之后就可以正常从程序坞打开了。

## 功能

- **单词**：每组 5 个词，先集中学习，再测「选意思 → 假名读音 → 汉字书写」，最后打勾清单。按间隔重复安排复习，当天答对的词不再出现。
- **学习进度**：默认从 Unit1 第1回开始，在速度表右上角的齿轮里可以调整当前单元和每天的任务量。
- **手写汉字**：Mac 上可以把整块触控板当书写板。
- **复习模式**：按单元列出全部单词，选择题型后自测。
- **任务日志**：日历上记录考试和作业，显示倒计时。
- **口语练习**：10 段「先生と面談する」会话，老师先说，你用日语回答，检查目标句型；还有随机抽问的模拟面谈。
- **场景短语**：便利店、餐厅、学校、问路等常用表达。
- **皮肤**：10 个主题色、自定义背景图和毛玻璃面板。

学习记录只保存在你自己的设备上，可以在「我的」里导出备份。

## 自己构建

```bash
python3 tools/build.py          # 由 src/app.html + data/share.json 生成 docs/
zsh mac/make_share_app.sh       # 生成 Mac 版到 build/mac/
```

## 致谢

- 手写识别：[KanjiCanvas](https://github.com/asdfjkl/kanjicanvas)（MIT）
- 日语发音：OpenJTalk

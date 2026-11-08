# KanjiCanvas（手写识别）

- 来源：https://github.com/asdfjkl/kanjicanvas （commit a9214105，MIT 许可，见 LICENSE.txt）
- `kanji-canvas.js`、`ref-patterns.js`：原样复制自 docs/resources/javascript/
- `kana-strokes.json`：由仓库 hiragana/ katakana/ 目录的笔画 XML 转换（隔点取样），运行时在页面里算成识别模板，
  因为原版 ref-patterns.js 只带了 い 和 を 两个假名。

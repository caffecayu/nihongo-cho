"""Rebuild docs/index.html from src/app.html + data/share.json.  Run: python3 tools/build.py"""
import json, pathlib, shutil
root = pathlib.Path(__file__).resolve().parent.parent
data = json.loads((root / "data/share.json").read_text(encoding="utf-8"))
tpl = (root / "src/app.html").read_text(encoding="utf-8")
page = tpl.replace("__DATA__", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
shell = ('<!doctype html><html lang="zh"><head><meta charset="utf-8">'
         '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
         '<title>毎日にほんご帳</title>'
         '<style>:root{color-scheme:light;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom)}'
         'body{margin:0;font:14px system-ui,sans-serif}img{max-width:100%}[hidden]{display:none!important}</style></head><body>')
(root / "docs/index.html").write_text(shell + page + "</body></html>", encoding="utf-8")
shutil.copytree(root / "src/vendor", root / "docs/vendor", dirs_exist_ok=True)
print("ok -> docs/index.html")

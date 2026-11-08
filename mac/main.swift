// 毎日にほんご帳 — native macOS window around the local study server (tools/desktop.py).
// Starts the server if it is not already running, shows the app in a WKWebView,
// and stops the server again on quit (only if this app started it).
import Cocoa
import WebKit

let PORT = 8765
let BASE = URL(string: "http://127.0.0.1:\(PORT)/")!

// Transparent layer over the page while "trackpad writing" is on: receives raw trackpad touches
// (NSTouch.normalizedPosition = absolute 0…1 finger position) and swallows clicks/taps so they
// don't draw stray dots. Keyboard input still goes to the page.
final class TrackpadLayer: NSView {
    var onTouch: ((String, CGPoint, CGFloat) -> Void)?
    private var finger: (NSObjectProtocol & NSCopying)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private func send(_ phase: String, _ t: NSTouch) {
        let size = t.deviceSize
        onTouch?(phase, t.normalizedPosition, size.height > 0 ? size.width / size.height : 1.6)
    }
    override func touchesBegan(with event: NSEvent) {
        guard finger == nil, let t = event.touches(matching: .began, in: self).first else { return }
        finger = t.identity
        send("b", t)
    }
    override func touchesMoved(with event: NSEvent) {
        guard let f = finger, let t = event.touches(matching: .moved, in: self).first(where: { $0.identity.isEqual(f) }) else { return }
        send("m", t)
    }
    override func touchesEnded(with event: NSEvent) {
        guard let f = finger, let t = event.touches(matching: .ended, in: self).first(where: { $0.identity.isEqual(f) }) else { return }
        finger = nil
        send("e", t)
    }
    override func touchesCancelled(with event: NSEvent) {
        guard let f = finger, let t = event.touches(matching: .cancelled, in: self).first(where: { $0.identity.isEqual(f) }) else { return }
        finger = nil
        send("e", t)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var web: WKWebView!
    var container: NSView!
    var layer: TrackpadLayer?
    var cursorFrozen = false
    var server: Process?
    var root: URL!
    var quitting = false
    /// Share edition: the pages ship inside the app (Resources/web) and need no local server.
    let bundledPage = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web")

    func applicationDidFinishLaunching(_ note: Notification) {
        let path = Bundle.main.object(forInfoDictionaryKey: "StudyAppRoot") as? String ?? ""
        root = URL(fileURLWithPath: path)
        buildMenu()

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.userContentController.add(self, name: "trackpad")
        if bundledPage != nil {
            // local JSON / audio packs are fetched relative to the bundled page
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
            config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        }
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = false

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "毎日にほんご帳"
        window.minSize = NSSize(width: 380, height: 560)
        container = NSView()
        web.autoresizingMask = [.width, .height]
        container.addSubview(web)
        window.contentView = container
        web.frame = container.bounds
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let page = bundledPage {
            web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
            return
        }
        showMessage("正在启动…", detail: "第一次打开可能需要几秒钟")
        DispatchQueue.global().async { self.startServerAndLoad() }
    }

    // MARK: server
    func healthy() -> Bool {
        var req = URLRequest(url: BASE.appendingPathComponent("api/health"), timeoutInterval: 1)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if (resp as? HTTPURLResponse)?.statusCode == 200, let data,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               obj["desktop"] as? Bool == true { ok = true }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 2)
        return ok
    }

    func python() -> String? {
        ["/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
         "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func startServerAndLoad() {
        if !healthy(), let p = server, p.isRunning {
            // started earlier and still coming up (e.g. waiting on a macOS permission prompt)
            if !waitForServer(p) { return }
        } else if !healthy() {
            let script = root.appendingPathComponent("tools/desktop.py")
            guard FileManager.default.fileExists(atPath: script.path) else {
                return fail("找不到学习APP文件夹", detail: "应在：\(root.path)\n如果移动过文件夹，请重新运行 mac/make_mac_app.sh")
            }
            guard let py = python() else { return fail("没有找到 Python 3", detail: "请安装 Python 3.10 或以上") }
            let logDir = root.appendingPathComponent(".runtime")
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            let logURL = logDir.appendingPathComponent("app-server.log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let log = try? FileHandle(forWritingTo: logURL)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: py)
            p.arguments = [script.path, "--port", "\(PORT)"]
            p.currentDirectoryURL = root
            var env = ProcessInfo.processInfo.environment
            env["PYTHONUNBUFFERED"] = "1"
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            p.environment = env
            p.standardOutput = log
            p.standardError = log
            do { try p.run() } catch { return fail("本地服务启动失败", detail: error.localizedDescription) }
            server = p
            if !waitForServer(p) { return }
        }
        DispatchQueue.main.async { self.web.load(URLRequest(url: BASE)) }
    }

    /// Waits up to 2 minutes. After a few seconds, explains the likely macOS "access Documents folder" prompt.
    func waitForServer(_ p: Process) -> Bool {
        let logPath = root.appendingPathComponent(".runtime/app-server.log").path
        for i in 0..<480 {
            if healthy() { return true }
            if !p.isRunning {
                fail("本地服务没有启动成功", detail: "可以查看日志：\(logPath)\n端口 \(PORT) 可能被其他程序占用")
                return false
            }
            if i == 16 {
                DispatchQueue.main.async {
                    self.showMessage("正在等待 macOS 授权…",
                                     detail: "如果屏幕上弹出「毎日にほんご帳 想要访问“文稿”文件夹中的文件」，请点「允许」。\n学习APP放在“文稿”里，本地服务需要读取它。")
                }
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        fail("本地服务没有响应", detail: "如果刚才拒绝了访问“文稿”的请求，可以在 系统设置 › 隐私与安全性 › 文件和文件夹 里给「毎日にほんご帳」打开“文稿”，然后点重试。")
        return false
    }

    func fail(_ title: String, detail: String) {
        DispatchQueue.main.async { self.showMessage(title, detail: detail, retry: true) }
    }

    func showMessage(_ title: String, detail: String, retry: Bool = false) {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: "\n", with: "<br>")
        }
        let html = """
        <!doctype html><meta charset="utf-8"><style>
        :root{color-scheme:light dark}body{margin:0;height:100vh;display:grid;place-items:center;
        font:15px -apple-system,"PingFang SC",sans-serif;background:#f3f6f2;color:#23302a}
        @media(prefers-color-scheme:dark){body{background:#141a17;color:#e4ece6}}
        .b{text-align:center;max-width:460px;padding:24px}.m{width:64px;height:64px;margin:0 auto 18px;border-radius:16px;
        background:#2f7a55;color:#fff;display:grid;place-items:center;font:700 34px "Hiragino Maru Gothic ProN",sans-serif}
        h1{font-size:20px;margin:0 0 8px}p{opacity:.7;line-height:1.6;margin:0 0 16px}
        a{color:#2f7a55;font-weight:700}</style>
        <div class="b"><div class="m">帳</div><h1>\(esc(title))</h1><p>\(esc(detail))</p>
        \(retry ? "<a href=\"app://retry\">重试</a>" : "")</div>
        """
        web.loadHTMLString(html, baseURL: nil)
    }

    // MARK: navigation
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.allow) }
        if url.scheme == "app" {
            decisionHandler(.cancel)
            showMessage("正在启动…", detail: "")
            DispatchQueue.global().async { self.startServerAndLoad() }
            return
        }
        if action.shouldPerformDownload { return decisionHandler(.download) }
        if (url.scheme == "http" || url.scheme == "https") && url.host != "127.0.0.1" && url.host != "localhost" {
            NSWorkspace.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.beginSheetModal(for: window) { r in completionHandler(r == .OK ? panel.url : nil) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { stopTrackpad(notifyPage: false); webView.reload() }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { stopTrackpad(notifyPage: false) }

    // target=_blank links (e.g. Forvo) open in the default browser
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { r in completionHandler(r == .OK ? panel.urls : nil) }
    }

    // Speaking practice records your answer in the page; only the local study page may use the microphone.
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let local = (origin.host == "127.0.0.1" && origin.port == PORT) || (bundledPage != nil && origin.protocol == "file")
        decisionHandler(local && type == .microphone ? .grant : .deny)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = NSAlert(); a.messageText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24)); field.stringValue = defaultText ?? ""
        a.accessoryView = field; a.addButton(withTitle: "好"); a.addButton(withTitle: "取消")
        a.window.initialFirstResponder = field
        a.beginSheetModal(for: window) { r in completionHandler(r == .alertFirstButtonReturn ? field.stringValue : nil) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = NSAlert(); a.messageText = message
        a.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = NSAlert(); a.messageText = message
        a.addButton(withTitle: "好"); a.addButton(withTitle: "取消")
        a.beginSheetModal(for: window) { r in completionHandler(r == .alertFirstButtonReturn) }
    }

    // MARK: trackpad writing
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "trackpad", let body = message.body as? [String: Any] else { return }
        if body["on"] as? Bool == true {
            let x = body["x"] as? Double ?? Double(web.bounds.midX)
            let y = body["y"] as? Double ?? Double(web.bounds.midY)
            startTrackpad(at: CGPoint(x: x, y: y))
        } else {
            stopTrackpad(notifyPage: false)
        }
    }

    func startTrackpad(at pagePoint: CGPoint) {
        if layer == nil {
            let l = TrackpadLayer(frame: container.bounds)
            l.autoresizingMask = [.width, .height]
            l.onTouch = { [weak self] phase, p, aspect in
                self?.web.evaluateJavaScript("window.__tp&&__tp('\(phase)',\(p.x),\(p.y),\(aspect))")
            }
            container.addSubview(l, positioned: .above, relativeTo: web)
            layer = l
        }
        window.makeFirstResponder(web)
        // Park the cursor over the writing pad and keep it there, so finger movement only writes.
        let inWindow = web.convert(pagePoint, to: nil)
        let onScreen = window.convertPoint(toScreen: inWindow)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? onScreen.y
        CGWarpMouseCursorPosition(CGPoint(x: onScreen.x, y: primaryHeight - onScreen.y))
        if !cursorFrozen { CGAssociateMouseAndMouseCursorPosition(0); cursorFrozen = true }
    }

    func stopTrackpad(notifyPage: Bool) {
        layer?.removeFromSuperview()
        layer = nil
        if cursorFrozen { CGAssociateMouseAndMouseCursorPosition(1); cursorFrozen = false }
        if notifyPage { web.evaluateJavaScript("window.__tpStopped&&__tpStopped()") }
    }

    func applicationDidResignActive(_ note: Notification) { if layer != nil { stopTrackpad(notifyPage: true) } }

    // MARK: lifecycle
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ app: NSApplication) -> NSApplication.TerminateReply {
        if quitting { return .terminateNow }
        quitting = true
        // Save the latest answers to disk before the server stops.
        web.evaluateJavaScript("typeof flush==='function'&&dirty?(clearTimeout(saveTimer),flush().then(()=>1)):0") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { app.reply(toApplicationShouldTerminate: true) }
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ note: Notification) {
        if cursorFrozen { CGAssociateMouseAndMouseCursorPosition(1) }
        if let p = server, p.isRunning {
            p.terminate()  // SIGTERM: desktop.py shuts down the speech engine too
            let deadline = Date().addingTimeInterval(3)
            while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        }
    }

    // MARK: menu
    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 毎日にほんご帳", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 毎日にほんご帳", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let view = NSMenu(title: "显示")
        view.addItem(withTitle: "重新载入", action: #selector(reload), keyEquivalent: "r")
        view.addItem(withTitle: "全屏", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f").keyEquivalentModifierMask = [.command, .control]
        viewItem.submenu = view

        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "窗口")
        win.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = win
        NSApp.mainMenu = main
    }

    @objc func reload() {
        if web.url?.host == "127.0.0.1" { web.reload() }
        else { DispatchQueue.global().async { self.startServerAndLoad() } }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

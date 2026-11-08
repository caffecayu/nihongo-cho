// Draws the 1024px app icon: green rounded square with 帳, like the sidebar mark.
import Cocoa

let out = CommandLine.arguments[1]
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(red: 0.24, green: 0.56, blue: 0.40, alpha: 1),
           ending: NSColor(red: 0.16, green: 0.43, blue: 0.30, alpha: 1))!.draw(in: path, angle: -90)
NSShadow().set()
// grid lines like 原稿用紙
NSColor.white.withAlphaComponent(0.13).setStroke()
let g = NSBezierPath(); g.lineWidth = 6
let inner = rect.insetBy(dx: 150, dy: 150)
g.appendRect(inner)
g.move(to: NSPoint(x: inner.midX, y: inner.minY)); g.line(to: NSPoint(x: inner.midX, y: inner.maxY))
g.move(to: NSPoint(x: inner.minX, y: inner.midY)); g.line(to: NSPoint(x: inner.maxX, y: inner.midY))
g.stroke()
let font = NSFont(name: "HiraMaruProN-W4", size: 500) ?? NSFont.boldSystemFont(ofSize: 500)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
let str = NSAttributedString(string: "帳", attributes: attrs)
let sz = str.size()
str.draw(at: NSPoint(x: (S - sz.width) / 2, y: (S - sz.height) / 2 + 10))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))

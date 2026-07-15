import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)

let bg = NSGradient(colors: [
    NSColor(calibratedRed: 0.05, green: 0.28, blue: 0.44, alpha: 1.0),
    NSColor(calibratedRed: 0.00, green: 0.52, blue: 0.56, alpha: 1.0)
])!
bg.draw(in: rect, angle: 55)

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.25)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()

let panel = NSBezierPath(roundedRect: NSRect(x: 120, y: 170, width: 784, height: 700), xRadius: 120, yRadius: 120)
NSColor(calibratedWhite: 1.0, alpha: 0.92).setFill()
panel.fill()

NSGraphicsContext.current?.saveGraphicsState()
NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.55, alpha: 1.0).setFill()
let tab = NSBezierPath(roundedRect: NSRect(x: 200, y: 700, width: 300, height: 110), xRadius: 50, yRadius: 50)
tab.fill()
NSGraphicsContext.current?.restoreGraphicsState()

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 350, y: 480))
arrow.line(to: NSPoint(x: 674, y: 480))
arrow.line(to: NSPoint(x: 674, y: 400))
arrow.line(to: NSPoint(x: 780, y: 520))
arrow.line(to: NSPoint(x: 674, y: 640))
arrow.line(to: NSPoint(x: 674, y: 560))
arrow.line(to: NSPoint(x: 350, y: 560))
arrow.close()

NSColor(calibratedRed: 0.03, green: 0.50, blue: 0.45, alpha: 1.0).setFill()
arrow.fill()

let dot = NSBezierPath(ovalIn: NSRect(x: 260, y: 470, width: 110, height: 110))
NSColor(calibratedRed: 0.96, green: 0.66, blue: 0.17, alpha: 1.0).setFill()
dot.fill()

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let pngData = rep.representation(using: .png, properties: [:])!
try pngData.write(to: URL(fileURLWithPath: "assets/icon-source.png"))

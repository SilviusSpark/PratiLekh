import AppKit
import Foundation
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Fluid/Assets.xcassets"
func render(_ size: Int, template: Bool) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 64, y: CGFloat(size) / 64)
    if !template {
        NSColor(srgbRed: 0.078, green: 0.420, blue: 0.369, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 60, height: 60), xRadius: 12, yRadius: 12).fill()
        context.translateBy(x: 8, y: 8)
        context.scaleBy(x: 0.75, y: 0.75)
    }
    (template ? NSColor.black : NSColor(srgbRed: 1, green: 0.996, blue: 0.980, alpha: 1)).setStroke()
    let document = NSBezierPath(roundedRect: NSRect(x: 12, y: 6, width: 40, height: 52), xRadius: 6, yRadius: 6)
    document.lineWidth = template ? 3.5 : 3
    document.stroke()
    let path = NSBezierPath()
    path.lineWidth = template ? 3.5 : 3
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: NSPoint(x: 22, y: 43)); path.line(to: NSPoint(x: 41, y: 43))
    path.move(to: NSPoint(x: 22, y: 34)); path.line(to: NSPoint(x: 34, y: 34))
    path.move(to: NSPoint(x: 29, y: 17)); path.line(to: NSPoint(x: 32, y: 25))
    path.line(to: NSPoint(x: 43, y: 36)); path.line(to: NSPoint(x: 47, y: 32))
    path.line(to: NSPoint(x: 36, y: 21)); path.close(); path.stroke()
    image.unlockFocus()
    return NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
}
let set = root + "/AppIcon.appiconset"
let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: set + "/Contents.json"))) as! [String: Any]
for item in json["images"] as! [[String: Any]] {
    guard let filename = item["filename"] as? String, let size = item["size"] as? String, let scale = item["scale"] as? String else { continue }
    let points = Int(size.split(separator: "x")[0])!
    let multiplier = Int(scale.prefix(1))!
    try render(points * multiplier, template: false).write(to: URL(fileURLWithPath: set + "/" + filename))
}
for scale in 1...3 {
    let filename = scale == 1 ? "menubar-icon.png" : "menubar-icon@\(scale)x.png"
    try render(18 * scale, template: true).write(to: URL(fileURLWithPath: root + "/MenuBarIcon.imageset/" + filename))
}

import SwiftUI

/// Original document and pen artwork, shared by product chrome and icon rendering.
struct PratiLekhMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let transform = CGAffineTransform(scaleX: rect.width / 64, y: rect.height / 64)
            .translatedBy(x: rect.minX, y: rect.minY)
        path.addRoundedRect(in: CGRect(x: 12, y: 6, width: 40, height: 52), cornerSize: CGSize(width: 6, height: 6))
        path.move(to: CGPoint(x: 22, y: 21))
        path.addLine(to: CGPoint(x: 41, y: 21))
        path.move(to: CGPoint(x: 22, y: 30))
        path.addLine(to: CGPoint(x: 34, y: 30))
        path.move(to: CGPoint(x: 29, y: 47))
        path.addLine(to: CGPoint(x: 32, y: 39))
        path.addLine(to: CGPoint(x: 43, y: 28))
        path.addLine(to: CGPoint(x: 47, y: 32))
        path.addLine(to: CGPoint(x: 36, y: 43))
        path.closeSubpath()
        return path.applying(transform)
    }
}

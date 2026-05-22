import SwiftUI

public struct LiveChart: View {
    public var history: [Double]
    public var color: Color
    public var maxVal: Double
    
    public init(history: [Double], color: Color, maxVal: Double = 100.0) {
        self.history = history
        self.color = color
        self.maxVal = maxVal
    }
    
    public var body: some View {
        GeometryReader { geo in
            if history.count > 1 {
                // Background Grid lines
                VStack {
                    Spacer()
                    Divider().opacity(0.1)
                    Spacer()
                    Divider().opacity(0.1)
                    Spacer()
                }
                
                // Line Path
                Path { path in
                    let step = geo.size.width / CGFloat(history.count - 1)
                    // Clamp values to prevent out of bounds drawing
                    let getClampedVal = { (index: Int) -> Double in
                        return min(max(history[index], 0), maxVal)
                    }
                    
                    let scale = geo.size.height / CGFloat(maxVal)
                    let startY = geo.size.height - CGFloat(getClampedVal(0)) * scale
                    path.move(to: CGPoint(x: 0, y: startY))
                    
                    for i in 1..<history.count {
                        let x = CGFloat(i) * step
                        let y = geo.size.height - CGFloat(getClampedVal(i)) * scale
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .background(
                    // Area Gradient Fill
                    Path { path in
                        let step = geo.size.width / CGFloat(history.count - 1)
                        let scale = geo.size.height / CGFloat(maxVal)
                        let getClampedVal = { (index: Int) -> Double in
                            return min(max(history[index], 0), maxVal)
                        }
                        
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for i in 0..<history.count {
                            let x = CGFloat(i) * step
                            let y = geo.size.height - CGFloat(getClampedVal(i)) * scale
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
            } else {
                Text("Veri yükleniyor...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

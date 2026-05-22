import SwiftUI

public struct CircularGauge: View {
    public var value: Double
    public var maxValue: Double
    public var title: String
    public var unit: String
    public var color: Color
    public var icon: String? = nil
    
    public var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(max(value / maxValue, 0.0), 1.0)))
                    .stroke(
                        AngularGradient(
                            colors: [color, color.opacity(0.7), color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
                
                VStack(spacing: 0) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 8))
                            .foregroundColor(color)
                    }
                    
                    Text(String(format: "%.0f", value))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 46, height: 46)
            
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

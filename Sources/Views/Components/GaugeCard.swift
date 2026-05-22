import SwiftUI

public struct GaugeCard<Content: View>: View {
    public var title: String
    public var icon: String
    public var value: String
    public var color: Color
    public var content: () -> Content
    
    public init(
        title: String,
        icon: String,
        value: String,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.value = value
        self.color = color
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

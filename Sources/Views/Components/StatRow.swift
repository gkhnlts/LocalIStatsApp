import SwiftUI

public struct StatRow: View {
    public var name: String
    public var value: String
    public var icon: String
    public var iconColor: Color
    
    public init(name: String, value: String, icon: String, iconColor: Color = .secondary) {
        self.name = name
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 16, height: 16)
                .background(iconColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Text(name)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    private var splashImageName: String {
        colorScheme == .dark ? "SplashAppIconDark" : "SplashAppIcon"
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()

                Image(splashImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: DesignTokens.Size.splashIconLarge, height: DesignTokens.Size.splashIconLarge)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                .scaleEffect(isVisible ? 1 : 0.8)
                .opacity(isVisible ? 1 : 0)
                
                Text("Shellbee")
                    .font(.system(size: DesignTokens.Size.splashTitle, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
                
                Spacer()
                
                ProgressView()
                    .controlSize(.regular)
                    .opacity(isVisible ? 1 : 0)
                
                Text("Connecting to Zigbee2MQTT")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .opacity(isVisible ? 1 : 0)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}

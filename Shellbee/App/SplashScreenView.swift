import SwiftUI

struct SplashScreenView: View {
    /// Devices received so far; the status line switches to them once the
    /// device list arrives.
    var deviceCount = 0

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
                    .shadow(color: .black.opacity(DesignTokens.Opacity.chipFill),
                            radius: DesignTokens.Shadow.splashRadius, y: DesignTokens.Shadow.splashY)
                .scaleEffect(isVisible ? 1 : 0.8)
                .opacity(isVisible ? 1 : 0)
                
                Text("Shellbee")
                    .font(.system(size: DesignTokens.Size.splashTitle, weight: .bold, design: .rounded))
                    .tracking(DesignTokens.Tracking.splashTitle)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
                
                Spacer()
                
                ProgressView()
                    .controlSize(.regular)
                    .opacity(isVisible ? 1 : 0)
                
                Text(deviceCount > 0 ? "Loading \(deviceCount) devices" : "Connecting to Zigbee2MQTT")
                    .contentTransition(.numericText())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .opacity(isVisible ? 1 : 0)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: DesignTokens.Duration.splashFadeIn)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}

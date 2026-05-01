import SwiftUI

struct HomeBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            if colorScheme == .dark {
                darkMesh.mask(fadeMask)
            } else {
                lightMesh.mask(fadeMask)
            }
        }
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.0),
                .init(color: .black, location: 0.75),
                .init(color: .black.opacity(DesignTokens.Opacity.secondaryDim), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var lightMesh: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.00, 0.00], [0.55, 0.00], [1.00, 0.00],
                    [0.00, 0.45], [0.60, 0.50], [1.00, 0.55],
                    [0.00, 1.00], [0.45, 1.00], [1.00, 1.00]
                ],
                colors: [
                    signatureLight,  signaturePale, signatureCool,
                    signatureMint,   signature,     signatureBlue,
                    signatureDeep,   signature,     signaturePale
                ],
                smoothsColors: true
            )
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(DesignTokens.Opacity.dimmedSurface), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
        } else {
            LinearGradient(
                colors: [signatureLight, signature, signatureDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(DesignTokens.Opacity.dimmedSurface), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
        }
    }

    @ViewBuilder
    private var darkMesh: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.00, 0.00], [0.55, 0.00], [1.00, 0.00],
                    [0.00, 0.45], [0.60, 0.50], [1.00, 0.55],
                    [0.00, 1.00], [0.45, 1.00], [1.00, 1.00]
                ],
                colors: [
                    darkLight,  darkPale,  darkCool,
                    darkMint,   darkBase,  darkBlue,
                    darkDeep,   darkBase,  darkPale
                ],
                smoothsColors: true
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(DesignTokens.Opacity.pressedAlpha), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
        } else {
            LinearGradient(
                colors: [darkLight, darkBase, darkDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(DesignTokens.Opacity.pressedAlpha), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
        }
    }

    private let signature      = Color(red: 227/255, green: 238/255, blue: 238/255)
    private let signatureLight = Color(red: 240/255, green: 246/255, blue: 246/255)
    private let signaturePale  = Color(red: 234/255, green: 242/255, blue: 242/255)
    private let signatureMint  = Color(red: 222/255, green: 240/255, blue: 234/255)
    private let signatureCool  = Color(red: 222/255, green: 236/255, blue: 240/255)
    private let signatureBlue  = Color(red: 220/255, green: 234/255, blue: 240/255)
    private let signatureDeep  = Color(red: 214/255, green: 232/255, blue: 232/255)

    private let darkBase  = Color(red:  4/255, green:  8/255, blue:  9/255)
    private let darkLight = Color(red:  8/255, green: 16/255, blue: 18/255)
    private let darkPale  = Color(red:  6/255, green: 12/255, blue: 14/255)
    private let darkMint  = Color(red:  5/255, green: 14/255, blue: 12/255)
    private let darkCool  = Color(red:  5/255, green: 12/255, blue: 16/255)
    private let darkBlue  = Color(red:  4/255, green: 10/255, blue: 18/255)
    private let darkDeep  = Color(red:  2/255, green:  6/255, blue:  8/255)
}

#Preview("Light") {
    HomeBackgroundGradient().ignoresSafeArea()
}

#Preview("Dark") {
    HomeBackgroundGradient()
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
}

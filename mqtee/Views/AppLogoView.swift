//
//  AppLogoView.swift
//  mqtee
//

import SwiftUI

struct AppLogoView: View {
    var size: CGFloat = 72
    var breathing: Bool = false

    @State private var isBreathing = false

    private var breathingScale: CGFloat {
        breathing && isBreathing ? 1.06 : 1.0
    }

    var body: some View {
        ZStack {
            if breathing {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BrandTheme.gradientStart.opacity(0.3),
                                BrandTheme.gradientEnd.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: size * 0.4,
                            endRadius: size * 0.75
                        )
                    )
                    .frame(width: size * 1.5, height: size * 1.5)
                    .scaleEffect(breathingScale)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            BrandTheme.gradientStart,
                            BrandTheme.gradientEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image("MQTeeLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.65, height: size * 0.65)
                .foregroundStyle(.white)
        }
        .scaleEffect(breathingScale)
        .shadow(color: .black.opacity(0.2), radius: size * 0.05, y: size * 0.02)
        .onAppear {
            guard breathing else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

// App name styled text
struct AppNameText: View {
    var size: Font = .largeTitle

    var body: some View {
        Text("MQTee")
            .font(size)
            .fontWeight(.bold)
    }
}

#Preview("Logo Small") {
    AppLogoView(size: 48)
        .padding()
}

#Preview("Logo Medium") {
    AppLogoView(size: 72)
        .padding()
}

#Preview("Logo Large") {
    AppLogoView(size: 128)
        .padding()
}

#Preview("Logo Breathing") {
    AppLogoView(size: 96, breathing: true)
        .padding(60)
}

#Preview("App Name") {
    VStack(spacing: 20) {
        AppNameText(size: .title)
        AppNameText(size: .largeTitle)
        AppNameText(size: .headline)
    }
    .padding()
}

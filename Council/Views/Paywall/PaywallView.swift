import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isLoadingOfferings = true
    @State private var showError = false
    @State private var errorMessage = ""

    let trigger: PaywallTrigger

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Hero
                        hero

                        // Value props
                        valueProps

                        // Packages
                        if let offering = subscriptionService.currentOffering {
                            packages(offering)
                        } else if isLoadingOfferings {
                            ProgressView()
                                .tint(AppColors.textSecondary)
                                .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 12) {
                                Text("Couldn't load plans")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppColors.textSecondary)
                                Button("Try Again") {
                                    Task {
                                        isLoadingOfferings = true
                                        await subscriptionService.fetchOfferings()
                                        if let offering = subscriptionService.currentOffering {
                                            selectedPackage = offering.annual ?? offering.availablePackages.first
                                        }
                                        isLoadingOfferings = false
                                    }
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.accent)
                            }
                            .padding(.vertical, 20)
                        }

                        // CTA
                        purchaseButton

                        // Footer
                        footer
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .task {
            await subscriptionService.fetchOfferings()
            if let offering = subscriptionService.currentOffering {
                selectedPackage = offering.annual ?? offering.availablePackages.first
            }
            isLoadingOfferings = false
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 16) {
            // Orb cluster as visual element
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.accent.opacity(0.08),
                                AppColors.background
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Three small orbs representing multi-coach
                ForEach(0..<3, id: \.self) { i in
                    let palette = AppColors.orbPalettes[i]
                    OrbAvatar(colors: palette, size: 36)
                        .offset(
                            x: CGFloat([-24, 24, 0][i]),
                            y: CGFloat([-12, -12, 16][i])
                        )
                }
            }
            .frame(height: 100)

            Text(trigger.headline)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(trigger.subtitle)
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .padding(.top, 8)
    }

    // MARK: - Value Props

    private var valueProps: some View {
        VStack(spacing: 0) {
            valuePropRow(
                icon: "person.2.fill",
                text: "Multi-coach sessions with distinct voices"
            )
            Divider().padding(.leading, 48)
            valuePropRow(
                icon: "infinity",
                text: "Unlimited sessions that remember you"
            )
            Divider().padding(.leading, 48)
            valuePropRow(
                icon: "link",
                text: "Notion integration for real-context coaching"
            )
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func valuePropRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Packages

    private func packages(_ offering: Offering) -> some View {
        VStack(spacing: 10) {
            ForEach(offering.availablePackages.sorted(by: { packageSortOrder($0) < packageSortOrder($1) })) { package in
                packageCard(package)
            }
        }
    }

    private func packageSortOrder(_ package: Package) -> Int {
        switch package.packageType {
        case .annual: return 0
        case .monthly: return 1
        default: return 2
        }
    }

    private func packageCard(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let isAnnual = package.packageType == .annual

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPackage = package
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(package.storeProduct.localizedTitle.isEmpty ? packageTitle(package) : package.storeProduct.localizedTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        if isAnnual {
                            Text("Best value")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.textPrimary)
                                .clipShape(Capsule())
                        }
                    }

                    Text(package.storeProduct.localizedPriceString + " / " + periodLabel(package))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Circle()
                    .strokeBorder(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 6 : 1.5)
                    .frame(width: 22, height: 22)
            }
            .padding(16)
            .background(isSelected ? AppColors.accent.opacity(0.04) : AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func packageTitle(_ package: Package) -> String {
        switch package.packageType {
        case .annual: return "Yearly"
        case .monthly: return "Monthly"
        default: return package.identifier
        }
    }

    private func periodLabel(_ package: Package) -> String {
        switch package.packageType {
        case .annual: return "year"
        case .monthly: return "month"
        case .weekly: return "week"
        default: return "period"
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard let package = selectedPackage else { return }
            Task {
                isPurchasing = true
                let success = await subscriptionService.purchase(package)
                isPurchasing = false
                if success {
                    dismiss()
                }
            }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppColors.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedPackage == nil || isPurchasing)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    isRestoring = true
                    let restored = await subscriptionService.restorePurchases()
                    isRestoring = false
                    if restored {
                        dismiss()
                    } else {
                        errorMessage = "No active subscription found."
                        showError = true
                    }
                }
            } label: {
                if isRestoring {
                    ProgressView()
                        .tint(AppColors.textTertiary)
                } else {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }
}

// MARK: - Trigger

enum PaywallTrigger {
    case multiCoach
    case notion
    case customCoach
    case sessionLimit
    case continuity
    case flagshipModel
    case general

    var headline: String {
        switch self {
        case .multiCoach:
            return "Multiple coaches.\nOne conversation."
        case .notion:
            return "Coaching that sees\nyour real work."
        case .customCoach:
            return "Build your own coach.\nShare it with the world."
        case .sessionLimit:
            return "Keep the\nmomentum going."
        case .continuity:
            return "Coaches that remember\nand compound."
        case .flagshipModel:
            return "Deeper thinking.\nBetter coaching."
        case .general:
            return "Unlock the full depth\nof AI coaching."
        }
    }

    var subtitle: String {
        switch self {
        case .multiCoach:
            return "Bring up to three coaches into a single session, each with their own voice and perspective."
        case .notion:
            return "Connect Notion so your coaches can reference your real workspace, projects, and notes."
        case .customCoach:
            return "Name it, define how it thinks, pick a voice, and share it with one link."
        case .sessionLimit:
            return "You've used your free sessions. Unlock unlimited coaching to keep building."
        case .continuity:
            return "Your coaches carry context across sessions, building on every conversation."
        case .flagshipModel:
            return "Access Claude, GPT-4o, and Gemini Pro for more nuanced, insightful coaching."
        case .general:
            return "Unlimited sessions, multi-coach calls, Notion integration, and coaches that remember you."
        }
    }
}

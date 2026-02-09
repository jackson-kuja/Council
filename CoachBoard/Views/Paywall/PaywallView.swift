import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorMessage = ""

    let trigger: PaywallTrigger

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    header

                    // Features
                    features

                    // Packages
                    if let offering = subscriptionService.currentOffering {
                        packages(offering)
                    }

                    // CTA
                    purchaseButton

                    // Restore + terms
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .task {
            await subscriptionService.fetchOfferings()
            // Pre-select annual
            if let offering = subscriptionService.currentOffering {
                selectedPackage = offering.annual ?? offering.availablePackages.first
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }
            .padding(20)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Council Premium")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Text(trigger.subtitle)
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 24)
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 16) {
            featureRow(icon: "infinity", title: "Unlimited sessions", desc: "No caps on coaching conversations")
            featureRow(icon: "person.2.fill", title: "Multi-coach sessions", desc: "Up to 3 coaches with distinct voices")
            featureRow(icon: "link", title: "Notion integration", desc: "Coaches that see your real workspace")
            featureRow(icon: "plus.circle.fill", title: "Create & share coaches", desc: "Build and share with one link")
            featureRow(icon: "brain.head.profile.fill", title: "Flagship AI models", desc: "Claude, GPT-4o, Gemini Pro")
            featureRow(icon: "clock.arrow.circlepath", title: "Session continuity", desc: "Coaches that remember and compound")
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Packages

    private func packages(_ offering: Offering) -> some View {
        VStack(spacing: 12) {
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(package.storeProduct.localizedTitle.isEmpty ? packageTitle(package) : package.storeProduct.localizedTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        if isAnnual {
                            Text("Save 33%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(package.storeProduct.localizedPriceString + " / " + periodLabel(package))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.border)
            }
            .padding(16)
            .background(AppColors.surface)
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
            .frame(height: 52)
            .background(AppColors.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedPackage == nil || isPurchasing)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
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

    var subtitle: String {
        switch self {
        case .multiCoach:
            return "Unlock multi-coach sessions. Multiple perspectives, one conversation."
        case .notion:
            return "Connect Notion so your coaches can see your real work."
        case .customCoach:
            return "Create and share your own coaches with the world."
        case .sessionLimit:
            return "You've used your free sessions this month. Unlock unlimited coaching."
        case .continuity:
            return "Unlock session continuity. Your coaches remember and compound."
        case .flagshipModel:
            return "Unlock flagship AI models for deeper, more nuanced coaching."
        case .general:
            return "Unlock the full depth of AI coaching."
        }
    }
}

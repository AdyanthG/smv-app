//
//  SubscriptionManager.swift
//  SMV
//
//  StoreKit 2 subscription management.
//  Ready for production once StoreKit configuration file is added.
//

import StoreKit
import SwiftUI

@Observable
final class SubscriptionManager {

    // MARK: - State

    enum SubscriptionTier: String {
        case free = "Free"
        case pro = "Pro"
        case elite = "Elite"
    }

    var currentTier: SubscriptionTier = .free
    var products: [Product] = []
    var isLoading = false
    var purchaseError: String?

    var isPro: Bool { currentTier == .pro || currentTier == .elite }
    var isElite: Bool { currentTier == .elite }

    // Product IDs — match your StoreKit config
    static let proMonthlyId = "com.adyanth.SMV.pro.monthly"
    static let proYearlyId = "com.adyanth.SMV.pro.yearly"
    static let eliteMonthlyId = "com.adyanth.SMV.elite.monthly"

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: [
                Self.proMonthlyId,
                Self.proYearlyId,
                Self.eliteMonthlyId,
            ])
        } catch {
            purchaseError = "Failed to load products"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase pending approval"
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        isLoading = false
    }

    // MARK: - Status

    func updateSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free

        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(entitlement) {
                if transaction.productID == Self.eliteMonthlyId {
                    highestTier = .elite
                } else if transaction.productID == Self.proMonthlyId ||
                          transaction.productID == Self.proYearlyId {
                    if highestTier != .elite { highestTier = .pro }
                }
            }
        }

        currentTier = highestTier
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        case .verified(let value):
            return value
        }
    }

    // MARK: - Feature Gates

    func canScan(monthlyCount: Int) -> Bool {
        if isPro { return true }
        return monthlyCount < 3 // Free tier: 3 scans/month
    }

    var canPostToForum: Bool { isPro }
    var canViewDetailedBreakdown: Bool { isPro }
    var canAccessAICoach: Bool { isElite }
}

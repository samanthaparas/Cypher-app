//
//  Subscription.swift
//  c705
//
//  Created for Subscription models
//
//  PURPOSE: Shapes for money features: subscription plans, producer earnings
//  and payouts. These are planned for a later version, since 1.0 does
//  not sell anything.
//

import Foundation

// The plan a user is on.
enum SubscriptionTier: String, Codable {
    case FREE
    case CREATOR_PLUS
    case PRO_CREATOR
}

struct SubscriptionResponse: Codable {
    let id: String?
    let userId: String?
    let tier: SubscriptionTier
    let productId: String?
    let expiresAt: String?
    let autoRenew: Bool
    let isActive: Bool
}

// A producer's money summary. Amounts are whole cents (500 means $5.00) to avoid decimal
// rounding mistakes.
struct ProducerEarningsResponse: Codable {
    let pendingBalance: Int // in cents
    let totalPaid: Int // in cents
    let totalEarnings: Int // in cents
    let availableForPayout: Int // in cents
    let pendingPurchases: Int
}

// One payout request: the total, the platform's cut, what the producer receives, and its
// status.
struct PayoutResponse: Codable {
    let id: String
    let producerId: String
    let totalAmount: Int
    let platformFee: Int
    let netAmount: Int
    let status: String
    let createdAt: String
}

// A producer's list of past payouts.
struct PayoutHistoryResponse: Codable {
    let payouts: [Payout]
    
    struct Payout: Codable, Identifiable {
        let id: String
        let producerId: String
        let totalAmount: Int
        let platformFee: Int
        let netAmount: Int
        let status: String
        let paymentMethod: String?
        let transactionId: String?
        let processedAt: String?
        let createdAt: String
    }
}


//
//  FareEstimatorTests.swift
//  RideBookingAppTests
//
//  Phase 16 — Testing, Security Rules & Final Packaging
//
//  Covers the fare formula itself (base + distance*rate + time*rate,
//  clamped to a minimum, rounded to cents) against the exact rate table
//  in Constants.Fare — if those rates ever change, these expected values
//  need updating too; that's intentional, it's what should catch an
//  accidental rate change breaking the receipt math.
//
//  SETUP: this file expects a RideBookingAppTests unit test target.
//  Xcode doesn't create one by default for a plain App template — add
//  one via File > New > Target… > Unit Testing Bundle (name it
//  RideBookingAppTests), then drag this file (and the other two test
//  files) into that target rather than the main app target.
//

import XCTest
import FirebaseFirestore
@testable import ride_app

final class FareEstimatorTests: XCTestCase {

    // MARK: - Economy: baseFare 2.00, perKm 0.80, perMinute 0.15, minimumFare 4.00

    func testEconomy_typicalTrip_computesEachComponent() {
        // 5 km, 12 min:
        // base = 2.00, distance = 5 * 0.80 = 4.00, time = 12 * 0.15 = 1.80
        // subtotal = 7.80 (above minimum, so total == subtotal)
        let estimate = FareEstimator.estimate(distanceKm: 5, durationMin: 12, vehicleType: .economy)

        XCTAssertEqual(estimate.baseFare, 2.00, accuracy: 0.001)
        XCTAssertEqual(estimate.distanceFare, 4.00, accuracy: 0.001)
        XCTAssertEqual(estimate.timeFare, 1.80, accuracy: 0.001)
        XCTAssertEqual(estimate.total, 7.80, accuracy: 0.001)
    }

    func testEconomy_veryShortTrip_clampsToMinimumFare() {
        // 0.5 km, 2 min: base 2.00 + distance 0.40 + time 0.30 = 2.70,
        // which is below the 4.00 minimum, so total should clamp to 4.00.
        let estimate = FareEstimator.estimate(distanceKm: 0.5, durationMin: 2, vehicleType: .economy)

        XCTAssertEqual(estimate.total, 4.00, accuracy: 0.001)
        // The component breakdown still reflects the raw (pre-clamp) math —
        // only `total` is clamped, so the receipt's line items stay honest.
        XCTAssertEqual(estimate.baseFare + estimate.distanceFare + estimate.timeFare, 2.70, accuracy: 0.001)
    }

    func testEconomy_zeroDistanceAndDuration_stillReturnsMinimumFare() {
        let estimate = FareEstimator.estimate(distanceKm: 0, durationMin: 0, vehicleType: .economy)
        XCTAssertEqual(estimate.total, 4.00, accuracy: 0.001)
    }

    // MARK: - Comfort & XL — confirms the vehicle-type multiplier actually applies

    func testComfort_costsMoreThanEconomy_forTheSameTrip() {
        let economy = FareEstimator.estimate(distanceKm: 10, durationMin: 20, vehicleType: .economy)
        let comfort = FareEstimator.estimate(distanceKm: 10, durationMin: 20, vehicleType: .comfort)
        XCTAssertGreaterThan(comfort.total, economy.total)
    }

    func testXL_costsMoreThanComfort_forTheSameTrip() {
        let comfort = FareEstimator.estimate(distanceKm: 10, durationMin: 20, vehicleType: .comfort)
        let xl = FareEstimator.estimate(distanceKm: 10, durationMin: 20, vehicleType: .xl)
        XCTAssertGreaterThan(xl.total, comfort.total)
    }

    // MARK: - Rounding

    func testTotal_isAlwaysRoundedToTwoDecimalPlaces() {
        // Pick inputs that would otherwise produce a longer decimal.
        let estimate = FareEstimator.estimate(distanceKm: 3.333, durationMin: 7.777, vehicleType: .economy)
        let rounded = (estimate.total * 100).rounded() / 100
        XCTAssertEqual(estimate.total, rounded, accuracy: 0.0001)
    }

    // MARK: - Phase 14 — Promo code discount math (PromoCode.discountAmount)

    func testPromoCode_percentageDiscount_appliesCorrectly() {
        let promo = PromoCode(
            id: nil,
            discountType: .percentage,
            value: 20,
            isActive: true,
            maxRedemptions: nil,
            redemptionCount: 0,
            expiresAt: nil
        )
        XCTAssertEqual(promo.discountAmount(onTotal: 10.00), 2.00, accuracy: 0.001)
    }

    func testPromoCode_flatDiscount_neverExceedsTheTotal() {
        let promo = PromoCode(
            id: nil,
            discountType: .flatAmount,
            value: 50,
            isActive: true,
            maxRedemptions: nil,
            redemptionCount: 0,
            expiresAt: nil
        )
        // A $50 flat discount on a $7.80 ride should clamp to $7.80, not
        // make the ride "negative cost".
        XCTAssertEqual(promo.discountAmount(onTotal: 7.80), 7.80, accuracy: 0.001)
    }

    func testPromoCode_expired_isNotRedeemable() {
        let promo = PromoCode(
            id: nil,
            discountType: .percentage,
            value: 10,
            isActive: true,
            maxRedemptions: nil,
            redemptionCount: 0,
            expiresAt: Timestamp(date: Date().addingTimeInterval(-3600))
        )
        XCTAssertFalse(promo.isRedeemable)
    }

    func testPromoCode_atMaxRedemptions_isNotRedeemable() {
        let promo = PromoCode(
            id: nil,
            discountType: .percentage,
            value: 10,
            isActive: true,
            maxRedemptions: 5,
            redemptionCount: 5,
            expiresAt: nil
        )
        XCTAssertFalse(promo.isRedeemable)
    }
}

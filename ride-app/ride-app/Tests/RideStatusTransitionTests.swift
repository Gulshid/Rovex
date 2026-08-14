//
//  RideStatusTransitionTests.swift
//  RideBookingAppTests
//
//  Phase 16 — Testing, Security Rules & Final Packaging
//
//  SCOPE NOTE — the actual transition logic (accept/start/complete/cancel)
//  lives in RideService, which talks to live Firestore (transactions,
//  snapshot listeners), and ActiveDriverRideViewModel/BookRideViewModel
//  both expose their `ride`/`phase` state as `private(set)`, so there's no
//  seam to inject a fake Ride into them without either standing up a
//  Firestore emulator or adding a protocol-based RideService abstraction
//  purely for testing. Both are reasonable next steps but out of scope
//  for this pass. What IS safely unit-testable without any of that:
//
//  1. RideStatus's raw string values — these are compared against literal
//     strings in firestore.rules ('requested', 'accepted', etc.) and in
//     Firestore queries (whereField("status", isEqualTo: ...)). A rename
//     of a case here without updating those two other places would fail
//     silently at runtime (queries just return zero results) rather than
//     at compile time — this test at least catches the Swift-side half of
//     that contract breaking.
//  2. BookRideViewModel.BookingPhase's Equatable synthesis, since Phase 14
//     added an associated Date value to `.scheduledConfirmation` and it's
//     worth confirming that doesn't quietly break the `phase == .idle`-
//     style comparisons already used throughout BookRideView.
//
//  See FareEstimatorTests.swift's header for the test-target setup note.
//

import XCTest
@testable import ride_app

final class RideStatusTransitionTests: XCTestCase {

    // MARK: - RideStatus raw value contract

    func testRideStatus_rawValues_matchFirestoreRulesAndQueries() {
        XCTAssertEqual(RideStatus.requested.rawValue, "requested")
        XCTAssertEqual(RideStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(RideStatus.ongoing.rawValue, "ongoing")
        XCTAssertEqual(RideStatus.completed.rawValue, "completed")
        XCTAssertEqual(RideStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(RideStatus.scheduled.rawValue, "scheduled")
    }

    func testRideStatus_decodesFromFirestoreStringExactly() throws {
        // Mirrors how Firestore's Codable support decodes the `status`
        // field on a real ride document.
        let decoder = JSONDecoder()
        let status = try decoder.decode(RideStatus.self, from: Data("\"ongoing\"".utf8))
        XCTAssertEqual(status, .ongoing)
    }

    // MARK: - BookingPhase equatable behavior

    func testBookingPhase_idleEqualsIdle() {
        XCTAssertEqual(BookRideViewModel.BookingPhase.idle, .idle)
    }

    func testBookingPhase_scheduledConfirmation_comparesByDate() {
        let date = Date()
        let a = BookRideViewModel.BookingPhase.scheduledConfirmation(date)
        let b = BookRideViewModel.BookingPhase.scheduledConfirmation(date)
        let c = BookRideViewModel.BookingPhase.scheduledConfirmation(date.addingTimeInterval(60))

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testBookingPhase_differentCasesAreNeverEqual() {
        XCTAssertNotEqual(BookRideViewModel.BookingPhase.idle, .searching)
        XCTAssertNotEqual(BookRideViewModel.BookingPhase.completed, .cancelled)
    }

    func testBookingPhase_failedComparesByMessage() {
        XCTAssertEqual(
            BookRideViewModel.BookingPhase.failed("network error"),
            BookRideViewModel.BookingPhase.failed("network error")
        )
        XCTAssertNotEqual(
            BookRideViewModel.BookingPhase.failed("network error"),
            BookRideViewModel.BookingPhase.failed("a different error")
        )
    }
}

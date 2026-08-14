//
//  AuthViewModelValidationTests.swift
//  RideBookingAppTests
//
//  Phase 16 — Testing, Security Rules & Final Packaging
//
//  Covers AuthViewModel.signUpValidationError — a pure computed property
//  with no Firebase calls, so it's testable in isolation without any
//  network/auth mocking. Doesn't test signUp()/signIn()/sendPasswordReset()
//  themselves since those hit AuthService → live FirebaseAuth; that would
//  need a proper AuthService abstraction/mock to test safely, which is a
//  reasonable next step but out of scope for this pass.
//
//  See FareEstimatorTests.swift's header for the test-target setup note.
//

import XCTest
@testable import ride_app

@MainActor
final class AuthViewModelValidationTests: XCTestCase {

    private func makeValidForm() -> AuthViewModel {
        let vm = AuthViewModel()
        vm.name = "Alex Rivera"
        vm.email = "alex@example.com"
        vm.password = "password123"
        vm.confirmPassword = "password123"
        return vm
    }

    func testValidForm_hasNoValidationError() {
        let vm = makeValidForm()
        XCTAssertNil(vm.signUpValidationError)
    }

    func testEmptyName_isRejected() {
        let vm = makeValidForm()
        vm.name = "   "
        XCTAssertEqual(vm.signUpValidationError, "Please enter your name.")
    }

    func testEmailWithoutAtSymbol_isRejected() {
        let vm = makeValidForm()
        vm.email = "alexexample.com"
        XCTAssertEqual(vm.signUpValidationError, "Please enter a valid email.")
    }

    func testEmailWithoutDot_isRejected() {
        let vm = makeValidForm()
        vm.email = "alex@examplecom"
        XCTAssertEqual(vm.signUpValidationError, "Please enter a valid email.")
    }

    func testPasswordUnderSixCharacters_isRejected() {
        let vm = makeValidForm()
        vm.password = "abc12"
        vm.confirmPassword = "abc12"
        XCTAssertEqual(vm.signUpValidationError, "Password must be at least 6 characters.")
    }

    func testPasswordExactlySixCharacters_isAccepted() {
        let vm = makeValidForm()
        vm.password = "abc123"
        vm.confirmPassword = "abc123"
        XCTAssertNil(vm.signUpValidationError)
    }

    func testMismatchedConfirmPassword_isRejected() {
        let vm = makeValidForm()
        vm.confirmPassword = "somethingElse123"
        XCTAssertEqual(vm.signUpValidationError, "Passwords don't match.")
    }

    // Validation checks run in a specific order (name → email → password
    // length → password match) — this pins that order down so a future
    // reordering is a deliberate, visible change rather than an accident.
    func testValidationChecksRunInExpectedOrder_nameBeforeEmail() {
        let vm = AuthViewModel()
        vm.name = ""
        vm.email = "not-an-email"
        vm.password = "password123"
        vm.confirmPassword = "password123"
        XCTAssertEqual(vm.signUpValidationError, "Please enter your name.")
    }

    func testSignIn_emptyFields_setsErrorWithoutNetworkCall() async {
        let vm = AuthViewModel()
        let result = await vm.signIn()
        XCTAssertNil(result)
        XCTAssertEqual(vm.errorMessage, "Please enter your email and password.")
    }

    func testForgotPassword_emptyEmail_setsErrorWithoutNetworkCall() async {
        let vm = AuthViewModel()
        let success = await vm.sendPasswordReset()
        XCTAssertFalse(success)
        XCTAssertEqual(vm.errorMessage, "Please enter your email.")
    }
}

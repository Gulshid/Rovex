//
//  AddressSearchViewModel.swift
//  RideBookingApp
//
//  Phase 6 — Maps, Location & Address Search
//
//  Bridges MKLocalSearchCompleter (which uses an old-style delegate API)
//  into a SwiftUI-friendly ObservableObject. Drives the autocomplete list
//  in AddressSearchView; resolving a tapped suggestion into an actual
//  coordinate happens via `resolve(_:)`.
//

import Foundation
import MapKit
import Combine

/// Lightweight, Identifiable-friendly wrapper around MKLocalSearchCompletion
/// so it can be used directly in a SwiftUI List.
struct AddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion
}

/// Result of resolving a suggestion (or the map's current region) into a
/// concrete point on the map.
struct ResolvedAddress {
    let address: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor
final class AddressSearchViewModel: NSObject, ObservableObject {

    @Published var queryText: String = "" {
        didSet { completer.queryFragment = queryText }
    }
    @Published private(set) var suggestions: [AddressSuggestion] = []
    @Published var isResolving = false
    @Published var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Bias suggestions toward the rider's current area (e.g. current location).
    func biasSearch(around coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance = 25_000) {
        completer.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )
    }

    /// Turns a tapped suggestion into an actual coordinate + formatted address.
    func resolve(_ suggestion: AddressSuggestion) async -> ResolvedAddress? {
        isResolving = true
        defer { isResolving = false }

        let searchRequest = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: searchRequest)

        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else {
                errorMessage = "No location found for that result."
                return nil
            }
            let coordinate = item.placemark.coordinate
            let address = item.placemark.formattedAddress.isEmpty
                ? suggestion.title
                : item.placemark.formattedAddress
            return ResolvedAddress(address: address, coordinate: coordinate)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

extension AddressSearchViewModel: MKLocalSearchCompleterDelegate {

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results.map {
                AddressSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.errorMessage = message
        }
    }
}

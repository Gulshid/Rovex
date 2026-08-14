//
//  AddressSearchView.swift
//  RideBookingApp
//
//  Phase 6 — Maps, Location & Address Search
//
//  Full-screen search sheet with live autocomplete (MKLocalSearchCompleter
//  via AddressSearchViewModel). Presented from MapBookingView for both the
//  pickup and drop-off fields; the field being edited is passed in so the
//  caller knows which one to update on selection.
//
//  UPDATED in Phase 14 — added Home/Work quick-select chips above the
//  search results when the signed-in user has saved a favorite location
//  (FavoriteLocationsView). Uses the coordinate saved alongside the
//  address (homeAddressGeoPoint/workAddressGeoPoint) directly rather than
//  re-geocoding on every tap.
//

import SwiftUI
import CoreLocation

struct AddressSearchView: View {

    let field: AddressField
    let onSelect: (ResolvedAddress) -> Void

    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = AddressSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    private var title: String {
        field == .pickup ? "Set pickup location" : "Set drop-off location"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                if hasFavorites {
                    favoritesRow
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                List(viewModel.suggestions) { suggestion in
                    Button {
                        Task { await select(suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(viewModel.isResolving)
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.suggestions.isEmpty && !viewModel.queryText.isEmpty {
                        ContentUnavailableView.search
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isSearchFocused = true }
            .overlay {
                if viewModel.isResolving {
                    ProgressView("Locating…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for an address", text: $viewModel.queryText)
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .submitLabel(.search)

            if !viewModel.queryText.isEmpty {
                Button {
                    viewModel.queryText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var hasFavorites: Bool {
        sessionManager.currentUser?.homeAddress?.isEmpty == false
            || sessionManager.currentUser?.workAddress?.isEmpty == false
    }

    private var favoritesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let home = sessionManager.currentUser?.homeAddress, !home.isEmpty,
                   let geoPoint = sessionManager.currentUser?.homeAddressGeoPoint {
                    favoriteChip(icon: "house.fill", label: "Home", address: home, coordinate: geoPoint.clCoordinate)
                }
                if let work = sessionManager.currentUser?.workAddress, !work.isEmpty,
                   let geoPoint = sessionManager.currentUser?.workAddressGeoPoint {
                    favoriteChip(icon: "briefcase.fill", label: "Work", address: work, coordinate: geoPoint.clCoordinate)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func favoriteChip(icon: String, label: String, address: String, coordinate: CLLocationCoordinate2D) -> some View {
        Button {
            onSelect(ResolvedAddress(address: address, coordinate: coordinate))
            dismiss()
        } label: {
            Label(label, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func select(_ suggestion: AddressSuggestion) async {
        guard let resolved = await viewModel.resolve(suggestion) else { return }
        onSelect(resolved)
        dismiss()
    }
}

#Preview {
    AddressSearchView(field: .pickup) { _ in }
        .environmentObject(SessionManager())
}

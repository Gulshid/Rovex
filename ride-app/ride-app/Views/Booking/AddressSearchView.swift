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

import SwiftUI
import CoreLocation

struct AddressSearchView: View {

    let field: AddressField
    let onSelect: (ResolvedAddress) -> Void

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
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search for an address or place", text: $viewModel.queryText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
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
        .padding()
    }

    private func select(_ suggestion: AddressSuggestion) async {
        guard let resolved = await viewModel.resolve(suggestion) else { return }
        onSelect(resolved)
        dismiss()
    }
}

#Preview {
    AddressSearchView(field: .pickup) { _ in }
}

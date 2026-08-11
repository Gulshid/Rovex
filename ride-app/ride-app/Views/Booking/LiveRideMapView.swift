//
//  LiveRideMapView.swift
//  RideBookingApp
//
//  Phase 9 — Real-Time Ride Tracking (Live Location)
//
//  Shared map component: pickup + drop-off pins, plus an animated car
//  marker at `driverCoordinate` that glides smoothly as the value updates
//  (SwiftUI's Map animates an Annotation's position automatically when the
//  coordinate for the same identity changes inside a withAnimation/implicit
//  animation context). Used by:
//   - DriverAssignedRideView (Rider side — Phase 7/9)
//   - ActiveDriverRideView (Driver side — Phase 8/9)
//   - RideTrackingView (Phase 9 standalone tracking)
//
//  FIXED — `.animation(...)` was originally chained onto the `Annotation`
//  inside the MapContentBuilder. Map content values (Marker, Annotation,
//  etc.) aren't plain SwiftUI `View`s, so `.animation()` doesn't resolve
//  there (that's the "has no member 'animation'" build error). The fix is
//  to apply `.animation(value:)` to the `Map` view itself instead — it
//  still animates the annotation's position because the Map's whole
//  content is re-evaluated on that value's change.
//

import SwiftUI
import MapKit
import CoreLocation

struct LiveRideMapView: View {

    let pickupCoordinate: CLLocationCoordinate2D?
    let dropoffCoordinate: CLLocationCoordinate2D?
    let driverCoordinate: CLLocationCoordinate2D?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasFitCamera = false

    var body: some View {
        Map(position: $cameraPosition) {
            if let pickupCoordinate {
                Marker("Pickup", systemImage: "circle.fill", coordinate: pickupCoordinate)
                    .tint(.green)
            }
            if let dropoffCoordinate {
                Marker("Drop-off", systemImage: "mappin", coordinate: dropoffCoordinate)
                    .tint(.red)
            }
            if let driverCoordinate {
                Annotation("Driver", coordinate: driverCoordinate) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(radius: 2)
                }
            }
        }
        // Animate the whole map's content whenever the driver's coordinate
        // changes — this is what makes the car marker glide instead of jump.
        .animation(.linear(duration: Constants.Tracking.driverLocationUpdateInterval), value: driverAnimationKey)
        .mapControls {
            MapCompass()
        }
        .onChange(of: fitKey) { _, _ in
            fitCameraIfNeeded()
        }
        .onAppear { fitCameraIfNeeded() }
    }

    /// Flattened, Equatable key so `.animation(value:)` has something
    /// concrete to compare (CLLocationCoordinate2D itself isn't Equatable).
    private var driverAnimationKey: String {
        guard let driverCoordinate else { return "-" }
        return "\(driverCoordinate.latitude),\(driverCoordinate.longitude)"
    }

    /// Same idea, but covering all three coordinates — used to know when to
    /// re-fit the camera (e.g. once pickup/drop-off first become available).
    private var fitKey: String {
        [pickupCoordinate, dropoffCoordinate, driverCoordinate]
            .map { $0.map { "\($0.latitude),\($0.longitude)" } ?? "-" }
            .joined(separator: "|")
    }

    private func fitCameraIfNeeded() {
        guard !hasFitCamera else { return }
        let coordinates = [pickupCoordinate, dropoffCoordinate, driverCoordinate].compactMap { $0 }
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let only = coordinates.first {
            cameraPosition = .region(
                MKCoordinateRegion(center: only, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            )
        } else {
            let rect = coordinates.reduce(MKMapRect.null) { partial, coordinate in
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return partial.union(pointRect)
            }
            cameraPosition = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.25))
        }
        hasFitCamera = true
    }
}

#Preview {
    LiveRideMapView(
        pickupCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        dropoffCoordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
        driverCoordinate: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.4144)
    )
    .frame(height: 300)
}

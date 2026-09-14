import SwiftUI
import MapKit
import CoreLocation

@available(iOS 17.0, *)
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: MKRoute?

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if let route {
                MapPolyline(route)
                    .stroke(.blue, lineWidth: 6)
            }

            Marker("Destination", coordinate: CLLocationCoordinate2D(latitude: 40.9312, longitude: -73.8987))
                .tint(.red)
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment: .bottom) {
            Button(action: updateCamera) {
                Text("Recenter Camera")
                    .font(.headline)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
            }
            .padding()
        }
    }

    private func updateCamera() {
        guard let userCoord = locationManager.location?.coordinate else { return }
        // Correct parameter order: heading before pitch
        cameraPosition = .camera(
            MapCamera(
                centerCoordinate: userCoord,
                distance: 400,
                heading: locationManager.heading,
                pitch: 60
            )
        )
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var heading: CLLocationDirection = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}

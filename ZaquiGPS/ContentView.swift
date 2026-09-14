import SwiftUI
import MapKit
import CoreLocation
import CarPlay

// MARK: - Models
struct SavedRoute: Identifiable, Codable {
    let id: UUID
    let title: String
    let distance: String
    let duration: String
}

// MARK: - Location Manager
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var speedMph: Int = 0
    @Published var heading: Double = 0.0
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
        let speed = location.speed
        speedMph = speed > 0 ? Int(speed * 2.23694) : 0
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}

// MARK: - Email Service
struct EmailService {
    static func sendRouteEmail(title: String, distance: String, duration: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send") else { return }
        
        let payload: [String: Any] = [
            "service_id": "Service_14gkfyk",
            "template_id": "YOUR_TEMPLATE_ID",
            "user_id": "YOUR_EMAILJS_PUBLIC_KEY",
            "template_params": [
                "to_email": "zacariasdejesusallentorres457@gmail.com",
                "route_title": title,
                "route_distance": distance,
                "route_time": duration,
                "message": "ZaquiGPS Alert: Route saved to vault!\nDestination: \(title)\nDistance: \(distance)\nTime: \(duration)"
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}

// MARK: - Main UI View
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var routes: [MKRoute] = []
    @State private var selectedRouteIndex = 0
    @State private var isNavigating = false
    @State private var isSatellite = false
    
    @State private var showAccountModal = false
    @State private var showRoutesModal = false
    @State private var savedRoutes: [SavedRoute] = []
    @State private var toastMessage: String?
    @State private var roadClosures: [CLLocationCoordinate2D] = []
    
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var isLoggedIn = false
    
    private let validBase32Secret = "JBSWY3DPEHPK3PXP"
    
    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                if let selectedDestination {
                    Marker(selectedDestination.name ?? "Destination", coordinate: selectedDestination.placemark.coordinate)
                        .tint(.cyan)
                }
                
                ForEach(routes.indices, id: \.self) { idx in
                    MapPolyline(routes[idx].polyline)
                        .stroke(idx == selectedRouteIndex ? Color.cyan : Color.gray.opacity(0.6), lineWidth: idx == selectedRouteIndex ? 7 : 4)
                }
                
                ForEach(roadClosures.indices, id: \.self) { idx in
                    Annotation("Closed", coordinate: roadClosures[idx]) {
                        Text("⛔").font(.title)
                    }
                }
            }
            .mapStyle(isSatellite ? .hybrid(elevation: .realistic) : .standard(elevation: .realistic))
            .ignoresSafeArea()
            
            VStack {
                if isNavigating {
                    navBannerView.padding(.top, 10)
                } else {
                    topSearchSection.padding(.top, 10)
                }
                Spacer()
            }
            
            VStack {
                HStack {
                    Spacer()
                    networkBadgeView
                        .padding(.trailing, 16)
                        .padding(.top, isNavigating ? 85 : 75)
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    speedometerCardView
                    Spacer()
                    floatingControlsView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, routes.isEmpty || isNavigating ? 30 : 160)
            }
            
            if !routes.isEmpty && !isNavigating {
                VStack {
                    Spacer()
                    routeBubbleView
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                }
            }
            
            if let toastMessage {
                VStack {
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.cyan)
                        .cornerRadius(20)
                        .shadow(radius: 6)
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { loadSavedRoutes() }
        .sheet(isPresented: $showAccountModal) { accountModalView }
        .sheet(isPresented: $showRoutesModal) { routesModalView }
    }
    
    private var networkBadgeView: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            Text("ONLINE (VALID BASE32 TOTP)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.green.opacity(0.5), lineWidth: 1))
    }
    
    private var navBannerView: some View {
        HStack(spacing: 16) {
            Text("⬆️")
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(Color(white: 0.2))
                .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDestination?.name ?? "Head toward route")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Real-Time Dynamic Navigation")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Button(action: endNavigation) {
                Text("End")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
    
    private var topSearchSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Where to?", text: $searchText)
                    .foregroundColor(.white)
                    .onChange(of: searchText) { newValue in performSearch(query: newValue) }
                if !searchText.isEmpty {
                    Button(action: { searchText = ""; searchResults = [] }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(15)
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button(action: { selectSearchItem(item) }) {
                                HStack(spacing: 12) {
                                    Text("📍")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown Location")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(item.placemark.title ?? "")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                            }
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.95))
                .cornerRadius(18)
                .frame(maxHeight: 220)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var speedometerCardView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(locationManager.speedMph)")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.green)
                Text("MPH").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            }
            
            VStack(spacing: 1) {
                Text("SPEED\nLIMIT")
                    .font(.system(size: 6.5, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                Text("45").font(.system(size: 18, weight: .black)).foregroundColor(.black)
            }
            .frame(width: 38, height: 48)
            .background(Color.white)
            .cornerRadius(6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
    
    private var floatingControlsView: some View {
        VStack(spacing: 12) {
            fabButton(icon: "🎯") { recenterMap() }
            fabButton(icon: "🔒") { showAccountModal = true }
            fabButton(icon: "🛣️") { showRoutesModal = true }
            fabButton(icon: "🗺️") {
                isSatellite.toggle()
                showToast(isSatellite ? "Esri World Imagery Active" : "Esri Street Map Active")
            }
            fabButton(icon: "⛔") { reportRoadClosed() }
        }
    }
    
    private func fabButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
    
    private var routeBubbleView: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(routes.indices, id: \.self) { idx in
                        let r = routes[idx]
                        let mins = Int(r.expectedTravelTime / 60)
                        Button(action: { selectedRouteIndex = idx }) {
                            Text(idx == 0 ? "🚀 Route 1 (\(mins)m)" : "🛣️ Route \(idx + 1) (\(mins)m)")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedRouteIndex == idx ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                                .foregroundColor(selectedRouteIndex == idx ? .cyan : .gray)
                                .cornerRadius(14)
                        }
                    }
                }
            }
            
            if !routes.isEmpty && selectedRouteIndex < routes.count {
                let currentRoute = routes[selectedRouteIndex]
                let mins = Int(currentRoute.expectedTravelTime / 60)
                let miles = String(format: "%.1f", currentRoute.distance / 1609.34)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(mins) min").font(.system(size: 26, weight: .heavy)).foregroundColor(.green)
                        Text("\(miles) mi").font(.system(size: 14)).foregroundColor(.gray)
                    }
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: { saveRoute(title: selectedDestination?.name ?? "Saved Route", distance: "\(miles) mi", time: "\(mins) min") }) {
                            Text("⭐ Save")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(16)
                        }
                        
                        Button(action: startNavigation) {
                            Text("GO")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.black)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(16)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }
    
    private var accountModalView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("🔒 Zaqui Cloud Security").font(.headline).foregroundColor(.white)
                Spacer()
                Button("✕") { showAccountModal = false }.foregroundColor(.gray)
            }
            if isLoggedIn {
                VStack(spacing: 12) {
                    Text("Connected: \(authEmail)").foregroundColor(.green)
                    Button(action: { showToast("Secret: \(validBase32Secret)") }) {
                        Text("Get 2FA Secret Key").foregroundColor(.cyan)
                    }
                    Button("Log Out") { isLoggedIn = false; showToast("Logged Out") }.foregroundColor(.red)
                }
            } else {
                VStack(spacing: 12) {
                    TextField("Email", text: $authEmail).padding().background(Color(white: 0.12)).cornerRadius(12)
                    SecureField("Password", text: $authPassword).padding().background(Color(white: 0.12)).cornerRadius(12)
                    Button("Sign In") {
                        if !authEmail.isEmpty { isLoggedIn = true; showToast("Logged in") }
                    }
                    .font(.bold(.body)())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
            }
            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .preferredColorScheme(.dark)
    }
    
    private var routesModalView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("🛣️ Saved Routes Vault").font(.headline).foregroundColor(.white)
                Spacer()
                Button("✕") { showRoutesModal = false }.foregroundColor(.gray)
            }
            if savedRoutes.isEmpty {
                Spacer()
                Text("Vault is empty").foregroundColor(.gray).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(savedRoutes) { route in
                    VStack(alignment: .leading) {
                        Text(route.title).font(.bold(.body)()).foregroundColor(.white)
                        Text("\(route.distance) • \(route.duration)").font(.caption).foregroundColor(.gray)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .padding(24)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .preferredColorScheme(.dark)
    }
    
    private func performSearch(query: String) {
        guard query.count >= 2 else { searchResults = []; return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            if let items = response?.mapItems { self.searchResults = items }
        }
    }
    
    private func selectSearchItem(_ item: MKMapItem) {
        selectedDestination = item
        searchResults = []
        searchText = item.name ?? ""
        calculateRoutes(to: item)
    }
    
    private func calculateRoutes(to destination: MKMapItem) {
        guard let userCoord = locationManager.userLocation else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoord))
        request.destination = destination
        request.requestsAlternateRoutes = true
        let directions = MKDirections(request: request)
        directions.calculate { response, _ in
            if let routes = response?.routes {
                self.routes = routes
                self.selectedRouteIndex = 0
            }
        }
    }
    
    private func startNavigation() {
        isNavigating = true
        if let userCoord = locationManager.userLocation {
            cameraPosition = .camera(MapCamera(centerCoordinate: userCoord, distance: 400, pitch: 60, heading: locationManager.heading))
        }
    }
    
    private func endNavigation() {
        isNavigating = false
        routes = []
        selectedDestination = nil
        searchText = ""
        recenterMap()
    }
    
    private func recenterMap() {
        if let userCoord = locationManager.userLocation {
            cameraPosition = .camera(MapCamera(centerCoordinate: userCoord, distance: 1000, pitch: 0))
        }
    }
    
    private func reportRoadClosed() {
        if let userCoord = locationManager.userLocation {
            roadClosures.append(userCoord)
            showToast("Road closure reported!")
        }
    }
    
    private func saveRoute(title: String, distance: String, time: String) {
        let newRoute = SavedRoute(id: UUID(), title: title, distance: distance, duration: time)
        savedRoutes.insert(newRoute, at: 0)
        if let encoded = try? JSONEncoder().encode(savedRoutes) {
            UserDefaults.standard.set(encoded, forKey: "zaquigps_saved_routes")
        }
        showToast("Route Saved to Vault!")
        
        EmailService.sendRouteEmail(title: title, distance: distance, duration: time) { success in
            showToast(success ? "Email dispatched! 🚀" : "Email failed")
        }
    }
    
    private func loadSavedRoutes() {
        if let data = UserDefaults.standard.data(forKey: "zaquigps_saved_routes"),
           let decoded = try? JSONDecoder().decode([SavedRoute].self, from: data) {
            savedRoutes = decoded
        }
    }
    
    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if toastMessage == msg { toastMessage = nil }
        }
    }
}

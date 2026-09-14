import SwiftUI

@main
struct ZaquiGPSApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "iphone.slash")
                        .font(.largeTitle)
                    Text("iOS 17.0+ Required")
                        .font(.headline)
                    Text("ZaquiGPS requires iOS 17.0 or newer to run.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

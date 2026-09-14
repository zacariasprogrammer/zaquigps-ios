import UIKit
import CarPlay
import MapKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSearchTemplateDelegate {
    var interfaceController: CPInterfaceController?
    var mapTemplate: CPMapTemplate?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let mapTemplate = CPMapTemplate()
        self.mapTemplate = mapTemplate

        let searchButton = CPBarButton(title: "Search") { [weak self] _ in
            let searchTemplate = CPSearchTemplate()
            searchTemplate.delegate = self
            self?.interfaceController?.pushTemplate(searchTemplate, animated: true, completion: nil)
        }

        mapTemplate.leadingNavigationBarButtons = [searchButton]
        interfaceController.setRootTemplate(mapTemplate, animated: true, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.mapTemplate = nil
    }

    // MARK: - Trip Preview Presentation

    func presentTripPreview(destinationCoordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: destinationCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Destination"

        let routeChoice = CPTrip(
            origin: MKMapItem.forCurrentLocation(),
            destination: mapItem,
            routeChoices: []
        )

        mapTemplate?.showTripPreviews([routeChoice], textConfiguration: nil)
    }

    // MARK: - CPSearchTemplateDelegate

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        guard !searchText.isEmpty else {
            completionHandler([])
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, error == nil else {
                completionHandler([])
                return
            }

            let items: [CPListItem] = response.mapItems.map { mapItem in
                let item = CPListItem(text: mapItem.name, detailText: mapItem.placemark.title)
                item.handler = { [weak self] _, completion in
                    self?.presentTripPreview(destinationCoordinate: mapItem.placemark.coordinate)
                    completion()
                }
                return item
            }

            completionHandler(items)
        }
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

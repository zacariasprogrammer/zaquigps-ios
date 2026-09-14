import CarPlay
import UIKit
import MapKit

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var mapTemplate: CPMapTemplate?
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        let map = CPMapTemplate()
        self.mapTemplate = map
        
        let searchBtn = CPBarButton(title: "Search") { [weak self] _ in
            self?.showCarPlaySearch()
        }
        let recenterBtn = CPBarButton(title: "Target") { [weak self] _ in
            self?.mapTemplate?.showTripPreviews([], selectedTripPreview: nil)
        }
        
        map.trailingNavigationBarButtons = [searchBtn, recenterBtn]
        interfaceController.setRootTemplate(map, animated: true, completion: nil)
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.mapTemplate = nil
    }
    
    private func showCarPlaySearch() {
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = self
        interfaceController?.pushTemplate(searchTemplate, animated: true, completion: nil)
    }
}

extension CarPlaySceneDelegate: CPSearchTemplateDelegate {
    func searchTemplate(_ searchTemplate: CPSearchTemplate, searchTextUpdated searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        guard !searchText.isEmpty else {
            completionHandler([])
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        let search = MKLocalSearch(request: request)
        
        search.start { response, _ in
            guard let items = response?.mapItems else {
                completionHandler([])
                return
            }
            
            let listItems = items.prefix(5).map { item -> CPListItem in
                let listItem = CPListItem(text: item.name ?? "Destination", detailText: item.placemark.title ?? "")
                listItem.handler = { [weak self] _, completion in
                    self?.startCarPlayNavigation(to: item)
                    completion()
                }
                return listItem
            }
            completionHandler(listItems)
        }
    }
    
    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    private func startCarPlayNavigation(to item: MKMapItem) {
        interfaceController?.popTemplate(animated: true, completion: nil)
        
        let placemark = MKPlacemark(coordinate: item.placemark.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.name
        
        let routeChoice = CPTrip(origin: MKMapItem.forCurrentLocation(), destination: mapItem, routeChoices: [])
        mapTemplate?.showTripPreviews([routeChoice], selectedTripPreview: routeChoice)
    }
}

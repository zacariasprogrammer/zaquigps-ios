import UIKit
import CarPlay
import MapKit

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var mapTemplate: CPMapTemplate?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let mapTemplate = CPMapTemplate()
        self.mapTemplate = mapTemplate

        let searchButton = CPBarButton(type: .image) { [weak self] _ in
            self?.presentSearchTemplate()
        }
        searchButton.image = UIImage(systemName: "magnifyingglass")
        mapTemplate.leadingNavigationBarButtons = [searchButton]

        let centerButton = CPMapButton { [weak self] _ in
            self?.mapTemplate?.dismissPanningInterface(animated: true)
        }
        centerButton.image = UIImage(systemName: "location.fill")
        mapTemplate.mapButtons = [centerButton]

        interfaceController.setRootTemplate(mapTemplate, animated: true, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.mapTemplate = nil
    }

    private func presentSearchTemplate() {
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = self
        interfaceController?.pushTemplate(searchTemplate, animated: true, completion: nil)
    }
}

extension CarPlaySceneDelegate: CPSearchTemplateDelegate {
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let mapItems = response?.mapItems else {
                completionHandler([])
                return
            }

            let items = mapItems.map { item -> CPListItem in
                let listItem = CPListItem(text: item.name, detailText: item.placemark.title)
                listItem.handler = { [weak self] _, completion in
                    self?.interfaceController?.popTemplate(animated: true, completion: nil)
                    completion()
                }
                return listItem
            }
            completionHandler(items)
        }
    }

    func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
        interfaceController?.popTemplate(animated: true, completion: nil)
    }
}

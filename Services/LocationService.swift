import Foundation
import CoreLocation

protocol LocationServiceDelegate: AnyObject {
    func didChangeAuth(status: CLAuthorizationStatus, precise: Bool)
    func didEnter(region: CLRegion)
    func didExit(region: CLRegion)
    func didVisit(_ visit: CLVisit)
    func didUpdateSignificant(_ location: CLLocation)
    func didFail(_ error: Error)
    func didDetermineState(_ state: CLRegionState, for region: CLRegion)
}

final class LocationService: NSObject {
    static let shared = LocationService()

    private let mgr = CLLocationManager()
    weak var delegate: LocationServiceDelegate?

    private override init() {
        super.init()
        mgr.delegate = self
        mgr.pausesLocationUpdatesAutomatically = true
        mgr.allowsBackgroundLocationUpdates = true
        mgr.activityType = .other
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUse() { mgr.requestWhenInUseAuthorization() }

    func requestAlways() { mgr.requestAlwaysAuthorization() }

    func startMonitoring(region: CLCircularRegion) {
        mgr.startMonitoring(for: region)
        mgr.requestState(for: region)
    }

    func stopMonitoring(region: CLCircularRegion) {
        mgr.stopMonitoring(for: region)
    }

    func monitoredRegions() -> [CLRegion] { Array(mgr.monitoredRegions) }

    func requestState(for region: CLRegion) { mgr.requestState(for: region) }

    func startSignificant() { mgr.startMonitoringSignificantLocationChanges() }
    func stopSignificant() { mgr.stopMonitoringSignificantLocationChanges() }

    func startVisits() { mgr.startMonitoringVisits() }
    func stopVisits() { mgr.stopMonitoringVisits() }

    func requestLocation() { mgr.requestLocation() }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let precise = manager.accuracyAuthorization == .fullAccuracy
        delegate?.didChangeAuth(status: status, precise: precise)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        delegate?.didEnter(region: region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        delegate?.didExit(region: region)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        delegate?.didVisit(visit)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        delegate?.didUpdateSignificant(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.didFail(error)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        delegate?.didDetermineState(state, for: region)
    }
}

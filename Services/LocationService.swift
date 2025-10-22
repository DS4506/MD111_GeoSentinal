
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

    private let manager = CLLocationManager()
    weak var delegate: LocationServiceDelegate?

    private override init() {
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = true
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = false
        manager.activityType = .other
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    // MARK: - Auth
    func requestWhenInUse() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: break
        }
        notifyAuthChanged()
    }

    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Monitoring
    func startMonitoring(region: CLCircularRegion) {
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    func stopMonitoring(region: CLCircularRegion) {
        manager.stopMonitoring(for: region)
    }

    func monitoredRegions() -> [CLRegion] {
        Array(manager.monitoredRegions)
    }

    // MARK: - Significant + Visits
    func startSignificant() { manager.startMonitoringSignificantLocationChanges() }
    func stopSignificant()  { manager.stopMonitoringSignificantLocationChanges() }
    func startVisits()      { manager.startMonitoringVisits() }
    func stopVisits()       { manager.stopMonitoringVisits() }

    // MARK: - Helpers
    private func notifyAuthChanged() {
        let precise = manager.accuracyAuthorization == .fullAccuracy
        delegate?.didChangeAuth(status: manager.authorizationStatus, precise: precise)
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        notifyAuthChanged()
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

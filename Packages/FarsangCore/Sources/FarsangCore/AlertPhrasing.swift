import Foundation

/// Banner, haptic and spoken text for each alert, following "Every alert" in the watch design.
enum AlertPhrasing {
    static func banner(for alert: Alert, unitSystem: UnitSystem) -> AlertBanner {
        let kind = alert.kind
        switch alert {
        case .turnAhead(_, let direction, let meters, let rawStreet):
            return turnBanner(direction: direction, meters: meters, street: rawStreet, unitSystem: unitSystem)
        case .offRoute(let heading):
            return AlertBanner(kind: kind, title: "Off route", detail: heading.map { "Head \($0.rawValue)" })
        case .backOnRoute:
            return AlertBanner(kind: kind, title: "Back on route")
        case .distanceMarker(let meters, let pace):
            let title = SpokenFormatter.distanceMarker(fromMeters: meters, unitSystem: unitSystem).capitalizedFirst
            let paceText = pace.flatMap { PaceFormatter.string(fromSecondsPerUnit: $0) }
            return AlertBanner(kind: kind, title: title, detail: paceText.map { "\($0) /\(unitSystem.unitSymbol)" })
        case .segmentMarked(let number):
            return AlertBanner(kind: kind, title: "Segment \(number)")
        case .paused:
            return AlertBanner(kind: kind, title: "Workout paused")
        case .resumed:
            return AlertBanner(kind: kind, title: "Workout resumed")
        case .ended:
            return AlertBanner(kind: kind, title: "Workout ended")
        }
    }

    private static func turnBanner(
        direction: TurnDirection, meters: Double, street rawStreet: String?, unitSystem: UnitSystem
    ) -> AlertBanner {
        let street = streetName(rawStreet)
        let distance =
            hasSayableDistance(meters, unitSystem: unitSystem)
            ? DistanceFormatter.string(fromMeters: meters, unitSystem: unitSystem) : nil
        let detail: String? =
            switch (distance, street) {
            case (let distance?, let street?): "In \(distance), \(street)"
            case (let distance?, nil): "In \(distance)"
            case (nil, let street?): street
            case (nil, nil): nil
            }
        return AlertBanner(kind: .turnAhead, title: "Turn \(direction.rawValue)", detail: detail)
    }

    /// Banner and speech share one rule: an unavailable distance (negative, not finite or too large to represent)
    /// is left out rather than shown or said wrongly.
    private static func hasSayableDistance(_ meters: Double, unitSystem: UnitSystem) -> Bool {
        SpokenFormatter.distance(fromMeters: meters, unitSystem: unitSystem) != nil
    }

    /// A blank street name is no street name.
    private static func streetName(_ street: String?) -> String? {
        guard let trimmed = street?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func haptic(for alert: Alert) -> AlertHaptic {
        switch alert {
        case .turnAhead(_, let direction, _, _): direction == .left ? .turnLeft : .turnRight
        case .offRoute: .longDoubleTap
        case .distanceMarker: .lightTap
        case .backOnRoute, .segmentMarked, .paused, .resumed, .ended: .singleTap
        }
    }

    static func spoken(for alert: Alert, unitSystem: UnitSystem) -> String {
        switch alert {
        case .turnAhead(_, let direction, let meters, let rawStreet):
            let street = streetName(rawStreet)
            let distance = SpokenFormatter.distance(fromMeters: meters, unitSystem: unitSystem)
            let lead = distance.map { "In \($0), turn" } ?? "Turn"
            let onto = street.map { " onto \($0)" } ?? ""
            return "\(lead) \(direction.rawValue)\(onto)"
        case .offRoute(let heading):
            return heading.map { "You're off route. Head \($0.rawValue)" } ?? "You're off route"
        case .backOnRoute:
            return "Back on route"
        case .distanceMarker(let meters, let pace):
            let marker = SpokenFormatter.distanceMarker(fromMeters: meters, unitSystem: unitSystem).capitalizedFirst
            let spokenPace = pace.map { SpokenFormatter.pace(fromSecondsPerUnit: $0, unitSystem: unitSystem) } ?? ""
            return spokenPace.isEmpty ? marker : "\(marker). \(spokenPace.capitalizedFirst)"
        case .segmentMarked(let number):
            return "Segment \(number)"
        case .paused:
            return "Workout paused"
        case .resumed:
            return "Workout resumed"
        case .ended:
            return "Workout ended"
        }
    }
}

extension String {
    fileprivate var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

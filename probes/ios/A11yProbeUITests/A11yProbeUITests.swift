import XCTest

/// Reads the accessibility tree of an app that is already on screen and runs Apple's accessibility audit on it.
/// Prints the a11y-native/v1 JSON as one base64 line between markers, which run.sh extracts from the log.
@MainActor
final class A11yProbeUITests: XCTestCase {

    private struct Walked {
        let path: String
        let snapshot: XCUIElementSnapshot
        let rect: [Double]
    }

    func testDump() throws {
        let env = ProcessInfo.processInfo.environment
        let bundleId = env["TARGET_BUNDLE_ID"] ?? ""
        guard !bundleId.isEmpty else {
            return XCTFail("TARGET_BUNDLE_ID is not set")
        }

        let app = XCUIApplication(bundleIdentifier: bundleId)
        // activate() launches an app that is not running; the probe only reads what is already on screen.
        guard app.state != .notRunning, app.state != .unknown else {
            return XCTFail("\(bundleId) is not running; start it and open the screen to check")
        }
        app.activate()

        var walked: [Walked] = []
        walk(try app.snapshot(), path: "0", into: &walked)

        // The runner has no launch screen, so its UIScreen reports a 320x480 compatibility screen. The application
        // element covers the real screen, and a screenshot of it gives the pixels per point.
        let appFrame = walked[0].snapshot.frame
        let pixels = XCUIScreen.main.screenshot().image.cgImage.map { max($0.width, $0.height) } ?? 0
        let points = max(appFrame.width, appFrame.height)
        let scale = pixels > 0 && points > 0 ? Double(pixels) / Double(points) : Double(UIScreen.main.scale)

        var found: [XCUIAccessibilityAuditIssue] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            found.append(issue)
            return true // keep the issue for the report instead of failing the test
        }
        // Resolved after the audit: its Dynamic Type checks resize the text while they run.
        let issues = found.map { issueJSON($0, walked) }

        let json: [String: Any] = [
            "schema": "a11y-native/v1",
            "platform": "ios",
            "device": env["SIMULATOR_UDID"] ?? "",
            "app": bundleId,
            "screen": [
                "width": round1(appFrame.width),
                "height": round1(appFrame.height),
                "scale": (scale * 1000).rounded() / 1000,
            ],
            "nodes": walked.map(nodeJSON),
            "issues": issues,
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let line = "A11Y_NATIVE_JSON_BEGIN\(data.base64EncodedString())A11Y_NATIVE_JSON_END\n"
        FileHandle.standardOutput.write(Data(line.utf8))
    }

    private func walk(_ snapshot: XCUIElementSnapshot, path: String, into out: inout [Walked]) {
        out.append(Walked(path: path, snapshot: snapshot, rect: rect(snapshot.frame)))
        for (i, child) in snapshot.children.enumerated() {
            walk(child, path: "\(path).\(i)", into: &out)
        }
    }

    private func nodeJSON(_ walked: Walked) -> [String: Any] {
        let s = walked.snapshot
        return [
            "path": walked.path,
            "nativeType": typeName(s.elementType),
            "role": role(s.elementType),
            "label": s.label,
            "value": string(s.value),
            "hint": s.placeholderValue ?? "",
            "identifier": s.identifier,
            "rect": walked.rect,
            "focusable": s.elementType != .other || !s.label.isEmpty,
            "clickable": clickable(s.elementType),
            "enabled": s.isEnabled,
            "selected": s.isSelected,
            "checked": NSNull(),
            "heading": NSNull(), // XCUITest does not expose traits
        ]
    }

    private func issueJSON(_ issue: XCUIAccessibilityAuditIssue, _ walked: [Walked]) -> [String: Any] {
        // snapshot() throws instead of failing the test when the element is gone.
        let element = try? issue.element?.snapshot()
        let issueRect = element.map { self.rect($0.frame) }
        // Several nodes can share a frame (a container and its only child); prefer the same type, then the deepest.
        let sameFrame = issueRect == nil ? [] : walked.filter { $0.rect == issueRect }
        let node = sameFrame.last { $0.snapshot.elementType == element?.elementType } ?? sameFrame.last
        return [
            "source": "apple",
            "check": checkName(issue.auditType),
            "severity": "error",
            "message": issue.detailedDescription.isEmpty ? issue.compactDescription : issue.detailedDescription,
            "nodePath": node?.path ?? NSNull(),
            "rect": issueRect ?? NSNull(),
        ]
    }

    private func role(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .button: "button"
        case .textField, .secureTextField, .searchField, .textView: "textField"
        case .switch, .toggle: "switch"
        case .slider: "slider"
        case .link: "link"
        case .image: "image"
        case .tab: "tab"
        case .checkBox: "checkbox"
        case .radioButton: "radio"
        case .staticText: "text"
        default: "other"
        }
    }

    private func clickable(_ type: XCUIElement.ElementType) -> Bool {
        switch type {
        case .button, .link, .textField, .secureTextField, .switch, .toggle, .slider, .cell, .tab, .checkBox,
             .radioButton, .menuItem, .segmentedControl, .stepper, .searchField:
            true
        default:
            false
        }
    }

    private func checkName(_ type: XCUIAccessibilityAuditType) -> String {
        switch type {
        case .contrast: "contrast"
        case .elementDetection: "elementDetection"
        case .hitRegion: "hitRegion"
        case .sufficientElementDescription: "sufficientElementDescription"
        case .dynamicType: "dynamicType"
        case .textClipped: "textClipped"
        case .trait: "trait"
        default: String(type.rawValue)
        }
    }

    private func typeName(_ type: XCUIElement.ElementType) -> String {
        let i = Int(type.rawValue)
        return Self.typeNames.indices.contains(i) ? Self.typeNames[i] : String(type.rawValue)
    }

    // Case names of XCUIElement.ElementType in raw-value order, 0...82 as in XCUIElementTypes.h.
    private static let typeNames = [
        "any", "other", "application", "group", "window", "sheet", "drawer", "alert", "dialog", "button",
        "radioButton", "radioGroup", "checkBox", "disclosureTriangle", "popUpButton", "comboBox", "menuButton",
        "toolbarButton", "popover", "keyboard", "key", "navigationBar", "tabBar", "tabGroup", "toolbar", "statusBar",
        "table", "tableRow", "tableColumn", "outline", "outlineRow", "browser", "collectionView", "slider",
        "pageIndicator", "progressIndicator", "activityIndicator", "segmentedControl", "picker", "pickerWheel",
        "switch", "toggle", "link", "image", "icon", "searchField", "scrollView", "scrollBar", "staticText",
        "textField", "secureTextField", "datePicker", "textView", "menu", "menuItem", "menuBar", "menuBarItem", "map",
        "webView", "incrementArrow", "decrementArrow", "timeline", "ratingIndicator", "valueIndicator", "splitGroup",
        "splitter", "relevanceIndicator", "colorWell", "helpTag", "matte", "dockItem", "ruler", "rulerMarker", "grid",
        "levelIndicator", "cell", "layoutArea", "layoutItem", "handle", "stepper", "tab", "touchBar", "statusItem",
    ]

    private func string(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        return value as? String ?? "\(value)"
    }

    // JSONSerialization cannot encode the infinite origin of a null frame.
    private func rect(_ frame: CGRect) -> [Double] {
        guard !frame.isNull, !frame.isInfinite else { return [0, 0, 0, 0] }
        return [frame.minX, frame.minY, frame.width, frame.height].map(round1)
    }

    private func round1(_ value: CGFloat) -> Double {
        value.isFinite ? (Double(value) * 10).rounded() / 10 : 0
    }
}

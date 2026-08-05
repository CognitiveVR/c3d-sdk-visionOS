//
//  DevicePropertiesTests.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Metal
import XCTest

@testable import Cognitive3DAnalytics

/// Coverage for the device signals reported with every session.
///
/// The SDK reports hardware values exactly as the operating system reports them; product names,
/// families and categories are resolved downstream. These tests exist to keep that property true:
/// they recompute each expected value from the operating system independently of the SDK, rather
/// than asserting against a constant the SDK could also be wrong about.
///
/// - Important: on a simulator these assertions describe the **host Mac**. They prove that the SDK
///   forwards what the operating system reports without altering it. They cannot prove what an
///   Apple Vision Pro reports — only a run on physical hardware can do that.
final class DevicePropertiesTests: XCTestCase {

    /// Product names and translated chip names that were previously hardcoded into the device
    /// signals. None of them may reappear in a device-identity field.
    private static let forbiddenClassificationStrings = [
        "Apple Vision Pro",
        "Apple Vision Pro (M2)",
        "Vision Pro",
        "Apple GPU",
        "Unknown Apple Device"
    ]

    private var core: MockCognitive3DAnalyticsCore!

    override func setUp() {
        super.setUp()
        core = MockCognitive3DAnalyticsCore()
        try? core.configure(with: CoreSettings(defaultSceneName: "TestScene", apiKey: "test_key"))
        core.clearNewSessionProperties()
    }

    override func tearDown() {
        core.clearNewSessionProperties()
        core = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Reads a `sysctl` string independently of the SDK, so the assertions below compare the SDK
    /// against the operating system rather than against themselves.
    private func referenceSysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: buffer)
    }

    private func deviceProperties() -> DeviceProperties {
        return createDeviceProperties(core: core)
    }

    // MARK: - Raw hardware signals

    func testHardwareModelIsReportedVerbatim() {
        let expected = referenceSysctlString("hw.model")
        XCTAssertFalse(
            expected.isEmpty,
            "hw.model returned nothing on this host; the rest of this assertion would be vacuous."
        )

        XCTAssertEqual(getRawHardwareModel(), expected, "hw.model must be forwarded verbatim.")

        let properties = deviceProperties()
        XCTAssertEqual(properties.deviceHardwareModel, expected)
        XCTAssertEqual(
            properties.toDictionary()["c3d.device.hw_model"] as? String,
            expected,
            "The hardware model must reach the payload unchanged."
        )
    }

    func testHardwareIdentityFieldsAllCarryTheRawHardwareModel() {
        let expected = referenceSysctlString("hw.model")
        let dict = deviceProperties().toDictionary()

        // This platform exposes exactly one hardware identifier, so every identity field carries
        // it. Previously each of these was a different hardcoded product name.
        XCTAssertEqual(dict["c3d.device.type"] as? String, expected)
        XCTAssertEqual(dict["c3d.device.model"] as? String, expected)
        XCTAssertEqual(dict["c3d.device.hmd.type"] as? String, expected)
    }

    func testCPUIsRawBrandStringAndIsNeverTranslated() {
        let expected = referenceSysctlString("machdep.cpu.brand_string")

        XCTAssertEqual(getRawCPUBrandString(), expected)
        XCTAssertEqual(
            deviceProperties().toDictionary()["c3d.device.cpu"] as? String,
            expected,
            "The CPU field must be the raw brand string, or empty when the key is unavailable."
        )
    }

    func testGPUIsTheMetalDeviceName() {
        let expected = MTLCreateSystemDefaultDevice()?.name ?? ""

        XCTAssertEqual(getRawGPUName(), expected)
        XCTAssertEqual(deviceProperties().toDictionary()["c3d.device.gpu"] as? String, expected)
    }

    func testNoDeviceIdentityFieldCarriesAHardcodedProductName() {
        let dict = deviceProperties().toDictionary()
        let identityKeys = [
            "c3d.device.type",
            "c3d.device.model",
            "c3d.device.hw_model",
            "c3d.device.hmd.type",
            "c3d.device.cpu",
            "c3d.device.gpu"
        ]

        for key in identityKeys {
            let value = dict[key] as? String ?? ""
            for forbidden in Self.forbiddenClassificationStrings {
                XCTAssertNotEqual(
                    value,
                    forbidden,
                    "\(key) reported the classified value '\(forbidden)' instead of a raw signal."
                )
            }
        }
    }

    // MARK: - Simulator flag

    func testSimulatorFlagMatchesTheBuildEnvironment() {
        #if targetEnvironment(simulator)
            let expected = true
        #else
            let expected = false
        #endif

        let dict = deviceProperties().toDictionary()
        XCTAssertEqual(dict["c3d.device.isSimulator"] as? Bool, expected)
        XCTAssertEqual(
            dict["c3d.app.inEditor"] as? Bool,
            expected,
            "The retained legacy key must keep carrying the same value as the new one."
        )
    }

    // MARK: - Memory units

    func testMemoryIsReportedInWholeGigabytes() {
        // Recomputed here from the standard binary gigabyte so that changing the divisor in the
        // SDK turns this test red.
        let expected = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        XCTAssertGreaterThan(expected, 0, "physicalMemory was under 1 GB; this host is implausible.")

        XCTAssertEqual(getTotalDeviceMemoryInGigabytes(), expected)
        XCTAssertEqual(deviceProperties().toDictionary()["c3d.device.memory"] as? Int, expected)
    }

    // MARK: - Struct / dictionary synchronisation

    func testDictionaryCarriesExactlyTheDeclaredKeys() {
        let dictKeys = Set(deviceProperties().toDictionary().keys)
        let declaredKeys = Set(DeviceProperties.CodingKeys.allCases.map { $0.rawValue })

        XCTAssertEqual(
            dictKeys,
            declaredKeys,
            "toDictionary() and CodingKeys disagree. A field was added to one and not the other; "
                + "missing: \(declaredKeys.subtracting(dictKeys)), extra: \(dictKeys.subtracting(declaredKeys))."
        )
    }

    func testDictionaryRoundTripIsLossless() {
        let original = deviceProperties()
        let dict = original.toDictionary()

        guard let restored = DeviceProperties.fromDictionary(dict) else {
            return XCTFail("fromDictionary() rejected a dictionary produced by toDictionary().")
        }

        let restoredDict = restored.toDictionary()
        XCTAssertEqual(Set(restoredDict.keys), Set(dict.keys))
        for (key, value) in dict {
            XCTAssertEqual(
                String(describing: restoredDict[key] ?? "<missing>"),
                String(describing: value),
                "Round trip lost or altered \(key)."
            )
        }
    }

    func testRoundTripFailsWhenARequiredKeyIsMissing() {
        var dict = deviceProperties().toDictionary()
        dict.removeValue(forKey: "c3d.device.hw_model")

        XCTAssertNil(
            DeviceProperties.fromDictionary(dict),
            "fromDictionary() must reject a payload that is missing the hardware model."
        )
    }

    // MARK: - Encoded payload

    func testEncodedJSONUsesTheWireKeys() throws {
        let data = try JSONEncoder().encode(deviceProperties())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(
            Set(json.keys),
            Set(DeviceProperties.CodingKeys.allCases.map { $0.rawValue }),
            "The encoded payload must carry exactly the declared wire keys."
        )
        XCTAssertEqual(json["c3d.device.hw_model"] as? String, referenceSysctlString("hw.model"))
    }
}

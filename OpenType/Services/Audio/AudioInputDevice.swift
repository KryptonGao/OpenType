import CoreAudio
import Foundation
import Observation

enum AudioInputTransport: String, Codable, Sendable, Equatable {
    case builtIn
    case bluetooth
    case usb
    case continuity
    case virtual
    case thunderbolt
    case aggregate
    case other

    init(coreAudioTransportType: UInt32) {
        switch coreAudioTransportType {
        case kAudioDeviceTransportTypeBuiltIn:
            self = .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            self = .bluetooth
        case kAudioDeviceTransportTypeUSB:
            self = .usb
        case kAudioDeviceTransportTypeContinuityCaptureWired,
             kAudioDeviceTransportTypeContinuityCaptureWireless,
             0x6363_6164: // 'ccad' Continuity Audio Device
            self = .continuity
        case kAudioDeviceTransportTypeVirtual:
            self = .virtual
        case kAudioDeviceTransportTypeThunderbolt:
            self = .thunderbolt
        case kAudioDeviceTransportTypeAggregate, kAudioDeviceTransportTypeAutoAggregate:
            self = .aggregate
        default:
            self = .other
        }
    }

    var badge: String? {
        switch self {
        case .builtIn: String(localized: "内置")
        case .bluetooth: String(localized: "蓝牙")
        case .usb: "USB"
        case .continuity: String(localized: "连续互通")
        case .virtual: String(localized: "虚拟")
        case .thunderbolt: "Thunderbolt"
        case .aggregate: String(localized: "聚合")
        case .other: nil
        }
    }

    var sortPriority: Int {
        switch self {
        case .builtIn: 0
        case .usb, .thunderbolt, .other: 1
        case .continuity: 2
        case .bluetooth: 3
        case .virtual, .aggregate: 4
        }
    }
}

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let deviceID: AudioDeviceID
    let uid: String
    let name: String
    let transport: AudioInputTransport
    let isDefault: Bool

    var id: String { uid }

    var displayName: String {
        guard let badge = transport.badge else { return name }
        return String(localized: "\(name)（\(badge)）")
    }
}

struct AudioInputTarget: Equatable, Sendable {
    let uid: String
    let name: String
}

enum AudioInputDeviceLookup {
    static func availableDevices() -> [AudioInputDevice] {
        let defaultID = defaultInputDeviceID()
        return allDeviceIDs().compactMap { deviceID in
            guard isAlive(deviceID), !isHidden(deviceID), inputChannelCount(deviceID) > 0,
                  let uid = deviceUID(deviceID), !uid.isEmpty else {
                return nil
            }
            let name = deviceName(deviceID) ?? uid
            let transport = AudioInputTransport(coreAudioTransportType: transportType(deviceID))
            return AudioInputDevice(
                deviceID: deviceID,
                uid: uid,
                name: name,
                transport: transport,
                isDefault: deviceID == defaultID
            )
        }
        .sorted { lhs, rhs in
            if lhs.transport.sortPriority != rhs.transport.sortPriority {
                return lhs.transport.sortPriority < rhs.transport.sortPriority
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        availableDevices().first(where: { $0.uid == uid })?.deviceID
    }

    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    private static func defaultInputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : AudioDeviceID(kAudioObjectUnknown)
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return devices
    }

    private static func inputChannelCount(_ deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buffer) == noErr else {
            return 0
        }
        let bufferList = buffer.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func isAlive(_ deviceID: AudioDeviceID) -> Bool {
        var alive: UInt32 = 1
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &alive) == noErr else {
            return true
        }
        return alive != 0
    }

    private static func isHidden(_ deviceID: AudioDeviceID) -> Bool {
        var hidden: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyIsHidden,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &hidden) == noErr else {
            return false
        }
        return hidden != 0
    }

    private static func transportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport) == noErr else {
            return 0
        }
        return transport
    }

    private static func deviceUID(_ deviceID: AudioDeviceID) -> String? {
        stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
    }

    private static func deviceName(_ deviceID: AudioDeviceID) -> String? {
        stringProperty(deviceID, selector: kAudioObjectPropertyName)
    }

    private static func stringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var ref: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &ref) == noErr, let ref else {
            return nil
        }
        return ref.takeRetainedValue() as String
    }
}

/// Observes CoreAudio input device changes (plug/unplug, system default switch) on the main actor.
@MainActor
@Observable
final class AudioInputMonitor {
    private(set) var devices: [AudioInputDevice]

    @ObservationIgnored private let fetchDevices: @Sendable () -> [AudioInputDevice]
    @ObservationIgnored private let listenerBox = ListenerBox()

    private final class ListenerBox: @unchecked Sendable {
        var listenerBlock: AudioObjectPropertyListenerBlock?
        let addresses = [
            AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
        ]

        deinit {
            guard let block = listenerBlock else { return }
            let systemObject = AudioObjectID(kAudioObjectSystemObject)
            for var address in addresses {
                AudioObjectRemovePropertyListenerBlock(systemObject, &address, .main, block)
            }
        }
    }

    init(
        fetchDevices: @escaping @Sendable () -> [AudioInputDevice] = { AudioInputDeviceLookup.availableDevices() },
        observeSystemChanges: Bool = true
    ) {
        self.fetchDevices = fetchDevices
        self.devices = fetchDevices()
        if observeSystemChanges {
            installListeners()
        }
    }

    var defaultDevice: AudioInputDevice? {
        devices.first(where: \.isDefault)
    }

    func refresh() {
        devices = fetchDevices()
    }

    func systemDefaultLabel() -> String {
        if let defaultDevice {
            return String(localized: "跟随系统（当前：\(defaultDevice.name)）")
        }
        return String(localized: "跟随系统")
    }

    func disconnectedLockedDevice(uid: String?, cachedName: String?) -> AudioInputTarget? {
        guard let uid, !uid.isEmpty, !devices.contains(where: { $0.uid == uid }) else {
            return nil
        }
        return AudioInputTarget(uid: uid, name: cachedName?.isEmpty == false ? cachedName! : uid)
    }

    func activeTransport(lockedUID: String?) -> AudioInputTransport? {
        if let lockedUID, !lockedUID.isEmpty {
            return devices.first(where: { $0.uid == lockedUID })?.transport
        }
        return defaultDevice?.transport
    }

    func menuSummaryLabel(lockedUID: String?, cachedName: String?) -> String {
        guard let lockedUID, !lockedUID.isEmpty else {
            if let defaultDevice {
                return String(localized: "麦克风：跟随系统（\(defaultDevice.name)）")
            }
            return String(localized: "麦克风：跟随系统")
        }
        if let device = devices.first(where: { $0.uid == lockedUID }) {
            return String(localized: "麦克风：\(device.name)")
        }
        let name = cachedName?.isEmpty == false ? cachedName! : lockedUID
        return String(localized: "麦克风：\(name)（未连接）")
    }

    private func installListeners() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        listenerBox.listenerBlock = block
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        for var address in listenerBox.addresses {
            AudioObjectAddPropertyListenerBlock(systemObject, &address, .main, block)
        }
    }
}

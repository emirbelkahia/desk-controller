//
//  BluetoothManager.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Foundation
@preconcurrency import CoreBluetooth

@MainActor
class BluetoothManager: NSObject {

    var stopOnFirstConnection = true

    // Singleton for managing it all
    static let shared = BluetoothManager()

    var centralManager: CBCentralManager?

    var onCentralManagerStateChange: (CBCentralManager?) -> Void = { _ in }

    var onConnectedPeripheralChange: (CBPeripheral?) -> Void = { _ in  }
    private var connectPeripheralRSSI: NSNumber?

    /// The peripheral we are attempting to connect to (set in didDiscover)
    private var pendingPeripheral: CBPeripheral?

    /// The peripheral that is fully connected (set in didConnect, cleared in didDisconnect)
    private(set) var connectedPeripheral: CBPeripheral?

    /// Target to apply once a force-reconnect finishes. AppleScript F17/F18
    /// fire-and-forget; the move has to resume after DeskController is rebuilt.
    var pendingMove: Position? {
        didSet { pendingMoveSetAt = pendingMove == nil ? nil : Date() }
    }
    private var pendingMoveSetAt: Date?

    /// Hand back the pending move and clear it. Returns nil if the request is
    /// older than `maxAge` — a reconnect that only succeeds hours later must
    /// not replay a stale F17/F18 and move the desk out of nowhere.
    func consumePendingMove(maxAge: TimeInterval = 30) -> Position? {
        defer { pendingMove = nil }
        guard let move = pendingMove, let setAt = pendingMoveSetAt,
              Date().timeIntervalSince(setAt) <= maxAge else {
            if pendingMove != nil {
                dbg("consumePendingMove: dropping stale pendingMove (age > \(Int(maxAge))s)")
            }
            return nil
        }
        return move
    }

    /// True between `cancelPeripheralConnection` and the following `didConnect`.
    /// Extra F-keys must not cancel an in-flight reconnect.
    private var reconnecting = false
    private var peripheralToRestore: CBPeripheral?
    private var reconnectTimeout: DispatchWorkItem?

    override init() {
        super.init()
        startScanning()
    }

    func startScanning() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
            return
        }
        scanForDesk()
    }

    func reconnect() {
        // Try connected peripheral first, then pending
        let peripheral = connectedPeripheral ?? pendingPeripheral
        guard let peripheral, peripheral.state == .disconnected else {
            return
        }
        pendingPeripheral = peripheral
        centralManager?.connect(peripheral, options: nil)
    }

    /// Tear down a zombie `.connected` link (writes may still land, GATT
    /// notifies don't) and connect again. Plain `reconnect()` is a no-op
    /// while `peripheral.state == .connected`.
    ///
    /// CoreBluetooth ignores `connect` until `didDisconnectPeripheral` fires.
    /// Calling both in the same turn leaves us with no peripheral at all —
    /// which is why F17/F18 looked dead after the first stale-notify attempt.
    func forceReconnect() {
        if reconnecting {
            dbg("forceReconnect: already in progress, keeping pendingMove")
            return
        }
        guard let peripheral = connectedPeripheral ?? pendingPeripheral else {
            dbg("forceReconnect: no peripheral — scanning")
            scanForDesk()
            return
        }
        reconnecting = true
        peripheralToRestore = peripheral
        pendingPeripheral = peripheral
        dbg("forceReconnect() cancel, wait for disconnect state=\(peripheral.state.rawValue) id=\(peripheral.identifier)")
        scheduleReconnectTimeout()
        centralManager?.cancelPeripheralConnection(peripheral)
    }

    /// Scan or adopt a desk macOS already holds. Safe to call when a
    /// CBCentralManager already exists (`startScanning()` used to no-op then).
    func scanForDesk() {
        guard let central = centralManager, central.state == .poweredOn else {
            if centralManager == nil {
                startScanning()
            }
            return
        }
        let alreadyConnected = central.retrieveConnectedPeripherals(
            withServices: [DeskPeripheral.deskControlServiceUUID]
        )
        if let desk = alreadyConnected.first {
            dbg("scanForDesk: adopting already-connected \(desk.identifier)")
            pendingPeripheral = desk
            central.connect(desk, options: nil)
            return
        }
        dbg("scanForDesk: scanning for advertisements")
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func scheduleReconnectTimeout() {
        reconnectTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.reconnecting else { return }
                dbg("forceReconnect: timeout — scanning")
                self.reconnecting = false
                self.scanForDesk()
            }
        }
        reconnectTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func finishReconnectAttempt() {
        reconnectTimeout?.cancel()
        reconnectTimeout = nil
        reconnecting = false
        peripheralToRestore = nil
    }
}

extension BluetoothManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            centralManager = central
            onCentralManagerStateChange(central)

            print("[BluetoothManager] state -> \(central.state.rawValue) (poweredOn=\(central.state == .poweredOn))")

            guard central.state == .poweredOn else {
                return
            }

            scanForDesk()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Extract Sendable primitives BEFORE crossing into the MainActor closure —
        // `advertisementData` is `[String: Any]` and can't be sent across isolations.
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let rssi = RSSI.intValue

        MainActor.assumeIsolated {
            let cachedName = peripheral.name
            // Match the desk's advertised name. Case-insensitive, and inspects
            // `CBAdvertisementDataLocalNameKey` too so a desk that hasn't been
            // paired before (and therefore has no `peripheral.name` yet) still
            // matches on the first scan.
            let looksLikeDesk = (cachedName?.lowercased().contains("desk") ?? false)
                || (localName?.lowercased().contains("desk") ?? false)

            guard pendingPeripheral != peripheral && connectedPeripheral != peripheral else {
                return
            }
            guard looksLikeDesk else { return }

            let isClosestMatchingPeripheral = (connectPeripheralRSSI != nil && rssi < connectPeripheralRSSI!.intValue)

            if pendingPeripheral == nil || isClosestMatchingPeripheral {
                central.connect(peripheral, options: nil)
                connectPeripheralRSSI = RSSI
                pendingPeripheral = peripheral
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            let isRestore = peripheral == pendingPeripheral || peripheral == peripheralToRestore
            guard isRestore else {
                dbg("didConnect ignored (not pending) id=\(peripheral.identifier)")
                return
            }

            dbg("didConnect id=\(peripheral.identifier) name=\(peripheral.name ?? "—")")
            finishReconnectAttempt()

            if stopOnFirstConnection {
                central.stopScan()
            }

            // Promote pending → connected
            connectedPeripheral = peripheral
            pendingPeripheral = nil
            onConnectedPeripheralChange(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            dbg("didDisconnect id=\(peripheral.identifier) error=\(error?.localizedDescription ?? "nil") reconnecting=\(reconnecting)")

            if peripheral == connectedPeripheral {
                connectedPeripheral = nil
            }
            connectPeripheralRSSI = nil
            onConnectedPeripheralChange(nil)

            // Connect only after disconnect — `connect` during `.connected`
            // is ignored by CoreBluetooth.
            if reconnecting {
                let target = peripheralToRestore ?? peripheral
                pendingPeripheral = target
                dbg("didDisconnect: reconnecting to \(target.identifier)")
                central.connect(target, options: nil)
                return
            }

            if peripheral == pendingPeripheral {
                pendingPeripheral = nil
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            dbg("didFailToConnect id=\(peripheral.identifier) error=\(error?.localizedDescription ?? "nil")")
            finishReconnectAttempt()
            if peripheral == pendingPeripheral {
                pendingPeripheral = nil
            }
            connectPeripheralRSSI = nil
            onConnectedPeripheralChange(nil)
            scanForDesk()
        }
    }

}

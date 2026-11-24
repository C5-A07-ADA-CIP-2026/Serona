import Foundation
@testable import Serona
import Testing

@MainActor
struct DeviceListViewModelTests {
    private let esp = DiscoveredDevice(id: UUID(), nama: "ESP 32")
    private let espB = DiscoveredDevice(id: UUID(), nama: "ESP 32-B")

    @Test("Scanning lists every device that was found, in order")
    func scanCollectsDevices() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(devices: [esp, espB]))

        await viewModel.scan()

        #expect(viewModel.devices == [esp, espB])
        #expect(!viewModel.isScanning)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("A device that is already connected when the list opens starts as the connected one")
    func startsWithConnectedDevice() async {
        let viewModel = DeviceListViewModel(
            service: StubDeviceConnectionService(devices: [esp, espB]),
            connectedDevice: esp
        )

        #expect(viewModel.connectedDevice == esp)

        await viewModel.scan()

        #expect(viewModel.connectedDevice == esp)
        #expect(viewModel.devices == [esp, espB])
    }

    @Test("Devices appear while the scan is still running")
    func devicesAppearWhileScanning() async {
        let (stream, continuation) = AsyncThrowingStream<DiscoveredDevice, any Error>.makeStream()
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(liveDevices: stream))

        let scan = Task { await viewModel.scan() }
        continuation.yield(esp)
        let didAppear = await waitUntil { viewModel.devices == [esp] }

        #expect(didAppear)
        #expect(viewModel.isScanning)

        continuation.finish()
        await scan.value
        #expect(!viewModel.isScanning)
    }

    @Test("A scan that finds nothing leaves an empty list and no error")
    func scanFindingNothing() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService())

        await viewModel.scan()

        #expect(viewModel.devices.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isScanning)
    }

    @Test("A failing scan reports the error and keeps what was already found")
    func scanFailureReportsError() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(
            devices: [esp],
            scanError: StubSaveError()
        ))

        await viewModel.scan()

        #expect(viewModel.devices == [esp])
        #expect(viewModel.errorMessage == "Gagal mencari perangkat: disk penuh")
        #expect(!viewModel.isScanning)
    }

    @Test("Scanning again does not list the same device twice")
    func rescanDoesNotDuplicateDevices() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(devices: [esp]))
        await viewModel.scan()

        await viewModel.scan()

        #expect(viewModel.devices == [esp])
    }

    @Test("A device found again with its real name is renamed in place, not listed twice")
    func rediscoveredDeviceTakesNewName() async {
        let id = UUID()
        let unnamed = DiscoveredDevice(id: id, nama: DiscoveredDevice.unnamed)
        let named = DiscoveredDevice(id: id, nama: "Serona-A1B2C3D4")
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(devices: [unnamed, named]))

        await viewModel.scan()

        #expect(viewModel.devices == [named])
    }

    @Test("Cancelling the task that runs the scan stops it")
    func cancellingScanTaskStopsScanning() async {
        let (stream, _) = AsyncThrowingStream<DiscoveredDevice, any Error>.makeStream()
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(liveDevices: stream))
        let scan = Task { await viewModel.scan() }
        let didStart = await waitUntil { viewModel.isScanning }
        #expect(didStart)

        scan.cancel()
        await scan.value

        #expect(!viewModel.isScanning)
    }

    @Test("Connecting marks the device as connected")
    func connectSucceeds() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(devices: [esp]))

        await viewModel.connect(esp)

        #expect(viewModel.connectedDevice == esp)
        #expect(viewModel.connectingDevice == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Disconnecting drops the connection and keeps the device in the list")
    func disconnectDropsConnection() async {
        let service = StubDeviceConnectionService(devices: [esp, espB])
        let viewModel = DeviceListViewModel(service: service)
        await viewModel.scan()
        await viewModel.connect(esp)

        await viewModel.disconnect()

        #expect(viewModel.connectedDevice == nil)
        #expect(viewModel.devices == [esp, espB])
        #expect(service.disconnectCounter.value == 1)
    }

    @Test("Disconnecting with nothing connected does nothing")
    func disconnectWithoutConnection() async {
        let service = StubDeviceConnectionService()
        let viewModel = DeviceListViewModel(service: service)

        await viewModel.disconnect()

        #expect(service.disconnectCounter.value == 0)
    }

    @Test("A failed connection reports the error and connects nothing")
    func connectFailureReportsError() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(connectError: StubSaveError()))

        await viewModel.connect(esp)

        #expect(viewModel.connectedDevice == nil)
        #expect(viewModel.connectingDevice == nil)
        #expect(viewModel.errorMessage == "Gagal menyambungkan ESP 32: disk penuh")
    }

    @Test("Cancelling a connection in progress is not an error")
    func cancelConnecting() async {
        let viewModel = DeviceListViewModel(service: StubDeviceConnectionService(connectSuspends: true))

        let connection = Task { await viewModel.connect(esp) }
        let didStart = await waitUntil { viewModel.connectingDevice == esp }
        #expect(didStart)

        viewModel.cancelConnecting()
        await connection.value

        #expect(viewModel.connectingDevice == nil)
        #expect(viewModel.connectedDevice == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("A second connection is ignored while one is in progress")
    func connectIgnoredWhileConnecting() async {
        let service = StubDeviceConnectionService(connectSuspends: true)
        let viewModel = DeviceListViewModel(service: service)
        let first = Task { await viewModel.connect(esp) }
        let didStart = await waitUntil { viewModel.connectingDevice == esp }
        #expect(didStart)

        await viewModel.connect(espB)
        let didReachService = await waitUntil { service.connectCounter.value >= 1 }

        #expect(didReachService)
        #expect(viewModel.connectingDevice == esp)
        #expect(service.connectCounter.value == 1)
        viewModel.cancelConnecting()
        await first.value
    }

    @Test("Connecting stops the running scan")
    func connectStopsScan() async {
        let (stream, _) = AsyncThrowingStream<DiscoveredDevice, any Error>.makeStream()
        let service = StubDeviceConnectionService(liveDevices: stream)
        let viewModel = DeviceListViewModel(service: service)
        let scan = Task { await viewModel.scan() }
        let didStart = await waitUntil { viewModel.isScanning }
        #expect(didStart)

        await viewModel.connect(esp)
        await scan.value

        #expect(!viewModel.isScanning)
        #expect(viewModel.connectedDevice == esp)
    }
}

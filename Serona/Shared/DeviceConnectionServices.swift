enum DeviceConnectionServices {
    static var `default`: any DeviceConnectionService {
        #if targetEnvironment(simulator)
            SimulatedDeviceConnectionService()
        #else
            BLEDeviceConnectionService.shared
        #endif
    }
}

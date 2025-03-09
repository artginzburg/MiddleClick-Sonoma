import CoreFoundation

// MARK: Multitouch API Bridging
typealias MTDeviceRef = CFTypeRef
typealias MTDevice = MTDeviceRef
typealias MTContactCallbackFunction = (
  Int32, UnsafeMutablePointer<Finger>?, Int32, Double, Int32
) -> Int32

struct mtPoint {
  let x: Float
  let y: Float
}

struct mtReadout {
  let pos: mtPoint
  let vel: mtPoint
}

struct Finger {
  let frame: Int32
  let timestamp: Double
  let identifier: Int32
  let state: Int32
  let foo3: Int32
  let foo4: Int32
  let normalized: mtReadout
  let size: Float
  let zero1: Int32
  let angle: Float
  let majorAxis: Float
  let minorAxis: Float
  let mm: mtReadout
  let zero2: (Int32, Int32)
  let unk2: Float
}

@_silgen_name("MTDeviceCreateDefault")
func MTDeviceCreateDefault() -> MTDevice

@_silgen_name("MTDeviceCreateList")
func MTDeviceCreateList() -> Unmanaged<CFMutableArray>!

@_silgen_name("MTDeviceRelease")
func MTDeviceRelease(_ device: MTDevice)

@_silgen_name("MTRegisterContactFrameCallback")
func MTRegisterContactFrameCallback(
  _ device: MTDevice, _ callback: MTContactCallbackFunction)

@_silgen_name("MTUnregisterContactFrameCallback")
func MTUnregisterContactFrameCallback(
  _ device: MTDevice, _ callback: MTContactCallbackFunction)

@_silgen_name("MTDeviceStart")
func MTDeviceStart(_ device: MTDevice, _ runMode: Int32)

@_silgen_name("MTDeviceStop")
func MTDeviceStop(_ device: MTDevice)

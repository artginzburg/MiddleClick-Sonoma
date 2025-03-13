// Reference:
//   - https://github.com/auramagi/everypinch/blob/44b74e6f34a525d5fa2661f5eddea1fb69fff51f/Package/Sources/MultitouchSupport/MultitouchSupport.h
//   - https://github.com/asmagill/hs._asm.undocumented.touchdevice/blob/master/MultitouchSupport.h
//   - https://github.com/Kyome22/OpenMultitouchSupport/blob/master/OpenMultitouchSupport/OpenMTInternal.h

#include <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>

CF_IMPLICIT_BRIDGING_ENABLED

CF_ASSUME_NONNULL_BEGIN

typedef struct {
	float x;
	float y;
} MTPoint;

typedef struct {
	MTPoint position;
	MTPoint velocity;
} MTVector;

typedef CF_ENUM (int, MTPathStage) {
    kMTPathStageNotTracking,
    kMTPathStageStartInRange,
    kMTPathStageHoverInRange,
    kMTPathStageMakeTouch,
    kMTPathStageTouching,
    kMTPathStageBreakTouch,
    kMTPathStageLingerInRange,
    kMTPathStageOutOfRange,
};

typedef struct {
    int frame;
    double timestamp;
    int identifier; // pathIndex
    MTPathStage stage;
    int fingerID;
    int handID;
    MTVector normalizedVector;
    float total;
    float pressure;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absoluteVector;
    int unknown14;
    int unknown15;
    float density;
} MTTouch;

typedef struct CF_BRIDGED_TYPE(id) MTDevice *MTDeviceRef;

typedef void (*MTFrameCallbackFunction)(MTDeviceRef device, MTTouch touches[], int numTouches, double timestamp, int frame);

//CFMutableArrayRef MTDeviceCreateList();

bool MTDeviceIsAlive(MTDeviceRef) CF_SWIFT_NAME(getter:MTDevice.isAlive(self:));
bool MTDeviceIsMTHIDDevice(MTDeviceRef) CF_SWIFT_NAME(getter:MTDevice.isMTHIDDevice(self:));
bool MTDeviceIsRunning(MTDeviceRef) CF_SWIFT_NAME(getter:MTDevice.isRunning(self:));

bool MTRegisterContactFrameCallback(MTDeviceRef, MTFrameCallbackFunction) CF_SWIFT_NAME(MTDevice.register(self:contactFrameCallback:));
bool MTUnregisterContactFrameCallback(MTDeviceRef, MTFrameCallbackFunction callback) CF_SWIFT_NAME(MTDevice.unregister(self:contactFrameCallback:));

void MTDeviceStart(MTDeviceRef, int runMode) CF_SWIFT_NAME(MTDevice.start(self:runMode:));
void MTDeviceStop(MTDeviceRef) CF_SWIFT_NAME(MTDevice.stop(self:));

void MTDeviceRelease(MTDeviceRef) CF_SWIFT_NAME(MTDevice.release(self:));

CF_ASSUME_NONNULL_END

CF_IMPLICIT_BRIDGING_DISABLED

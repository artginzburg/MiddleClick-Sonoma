#import "Controller.h"
#import "PreferenceKeys.h"
#import "TrayMenu.h"

int main(int argc, char* argv[])
{
  id keys[] = {
    kFingersNum,
    kMaxDistanceDelta,
    kMaxTimeDelta,
  };
  id objects[] = {
      [NSNumber numberWithInt:kFingersNumDefault],
      [NSNumber numberWithFloat:kMaxDistanceDeltaDefault],
      [NSNumber numberWithInt:kMaxTimeDelta],
  };
  NSUInteger count = sizeof(objects) / sizeof(id);
  NSDictionary *appDefaults = [NSDictionary
                               dictionaryWithObjects:objects
                               forKeys:keys
                               count:count];
  
  [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
  
  NSApplication* app = [NSApplication sharedApplication];
  
  Controller* con = [[Controller alloc] init];
  [con start];
  
  // add Menu Bar item
  TrayMenu* menu = [[TrayMenu alloc] initWithController:con];
  [app setDelegate:(id<NSApplicationDelegate>)menu];
  
  [app run];
  
  return EXIT_SUCCESS;
}

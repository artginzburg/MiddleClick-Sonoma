#import "TrayMenu.h"
#import "Controller.h"
#import <Cocoa/Cocoa.h>

@implementation TrayMenu

- (id)initWithController:(Controller*)ctrl
{
  [super init];
  myController = ctrl;
  [self setChecks];
  return self;
}

- (void)initAccessibilityPermissionStatus:(NSMenu*)menu
{
  BOOL hasAccessibilityPermission = AXIsProcessTrusted();

  [self updateAccessibilityPermissionStatus:menu
                 hasAccessibilityPermission:hasAccessibilityPermission];

  if (!hasAccessibilityPermission) {
    [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:NO block:^(NSTimer* timer) {
      [self initAccessibilityPermissionStatus:menu];
    }];
  }
}
- (void)updateAccessibilityPermissionStatus:(NSMenu*)menu
                 hasAccessibilityPermission:(BOOL)isTrusted
{
  _statusItem.button.appearsDisabled = !isTrusted;
  accessibilityPermissionStatusItem.hidden = isTrusted;
  accessibilityPermissionActionItem.hidden = isTrusted;
}

- (void)openWebsite:(id)sender
{
  NSURL* url = [NSURL
                URLWithString:@"https://github.com/artginzburg/MiddleClick-BigSur"];
  [[NSWorkspace sharedWorkspace] openURL:url];
}
- (void)openAccessibilitySettings:(id)sender
{
  BOOL isPreCatalina = (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_15);
  if (isPreCatalina) {
    NSAppleScript *a = [[NSAppleScript alloc] initWithSource:
                        @"tell application \"System Preferences\"\n"
                        "activate\n"
                        "reveal anchor \"Privacy_Accessibility\" of pane \"com.apple.preference.security\"\n"
                        "end tell"];
    [a executeAndReturnError:nil];
    [a release];
  } else {
    NSURL* url = [NSURL
                  URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:url];
  }
}

- (void)setClick:(id)sender
{
  [myController setMode:YES];
  [self setChecks];
}

- (void)setTap:(id)sender
{
  [myController setMode:NO];
  [self setChecks];
}

- (void)setChecks
{
  if ([myController getClickMode]) {
    [clickItem setState:NSControlStateValueOn];
    [tapItem setState:NSControlStateValueOff];
  } else {
    [clickItem setState:NSControlStateValueOff];
    [tapItem setState:NSControlStateValueOn];
  }
}

- (void)actionReload:(id)sender
{
  [myController scheduleRestart:0];
}

- (void)actionQuit:(id)sender
{
  [NSApp terminate:sender];
}

- (NSMenu*)createMenu
{
  NSMenu* menu = [NSMenu new];
  NSMenuItem* menuItem;
  
  
  
  int fingersQua = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"fingers"];
  
  [self createMenuAccessibilityPermissionItems:menu];
  
  // Add About
  menuItem = [menu addItemWithTitle:@"About MiddleClick..."
                             action:@selector(openWebsite:)
                      keyEquivalent:@""];
  [menuItem setTarget:self];
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  clickItem = [menu addItemWithTitle:[NSString stringWithFormat: @"%d Finger Click", fingersQua]
                              action:@selector(setClick:)
                       keyEquivalent:@""];
  [clickItem setTarget:self];
  
  tapItem = [menu addItemWithTitle:[NSString stringWithFormat: @"%d Finger Tap", fingersQua]
                            action:@selector(setTap:)
                     keyEquivalent:@""];
  [tapItem setTarget:self];
  
  [self setChecks];
  
  // Add Separator
  [menu addItem:[NSMenuItem separatorItem]];
  
  NSMenuItem* reloadItem = [menu addItemWithTitle:@"Reload"
                                            action:@selector(actionReload:)
                                     keyEquivalent:@"r"];
  [reloadItem setTarget:self];
  
  // Add Quit Action
  menuItem = [menu addItemWithTitle:@"Quit"
                             action:@selector(actionQuit:)
                      keyEquivalent:@"q"];
  [menuItem setTarget:self];
  
  return menu;
}

- (void)createMenuAccessibilityPermissionItems:(NSMenu *)menu
{
  accessibilityPermissionStatusItem = [menu addItemWithTitle:@"Missing Accessibility permission" action:nil keyEquivalent:@""];
  accessibilityPermissionActionItem = [menu addItemWithTitle:@"Open Privacy Preferences" action:@selector(openAccessibilitySettings:) keyEquivalent:@","];

  [menu addItem:[NSMenuItem separatorItem]];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
  NSMenu* menu = [self createMenu];
  
  NSImage* icon = [NSImage imageNamed:(@"StatusIcon")];
  [icon setSize:CGSizeMake(24, 24)];
  
  // Check if Darkmode menubar is supported and enable templating of the icon in
  // that case.
  
  BOOL oldBusted = (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_9);
  if (!oldBusted) {
    // 10.10 or higher, so setTemplate: is safe
    [icon setTemplate:YES];
  }
  
  _statusItem = [[[NSStatusBar systemStatusBar]
                  statusItemWithLength:24] retain];
  _statusItem.behavior = NSStatusItemBehaviorRemovalAllowed;
  _statusItem.menu = menu;
  _statusItem.button.toolTip = @"MiddleClick";
  _statusItem.button.image = icon;

  [self initAccessibilityPermissionStatus:menu];
  
  [menu release];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)flag
{
  _statusItem.visible = true;
  return 1;
}

@end

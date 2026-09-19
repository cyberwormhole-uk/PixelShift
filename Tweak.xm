#import <UIKit/UIKit.h>

#define kPrefsPath @"/var/mobile/Library/Preferences/com.yourname.pixelshift.plist"

@interface PixelShiftManager : NSObject
+ (instancetype)sharedManager;
- (void)start;
- (void)stop;
- (void)reloadPreferences;
@end

@implementation PixelShiftManager {
    NSTimer *_timer;
    NSInteger _phase;
    BOOL _enabled;
    CGFloat _amount;
    NSTimeInterval _interval;
}

+ (instancetype)sharedManager {
    static PixelShiftManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [PixelShiftManager new];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _phase = 0;
        [self reloadPreferences];

        // Reload prefs live when the user changes them in Settings
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            (CFNotificationCallback)PrefsChangedCallback,
            CFSTR("com.yourname.pixelshift/prefschanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer,
                                  CFStringRef name, const void *object,
                                  CFDictionaryRef userInfo) {
    PixelShiftManager *manager = (__bridge PixelShiftManager *)observer;
    [manager reloadPreferences];
    [manager stop];
    [manager start];
}

- (void)reloadPreferences {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];

    _enabled  = prefs[@"enabled"]      ? [prefs[@"enabled"] boolValue]      : YES;
    _amount   = prefs[@"shiftAmount"]  ? [prefs[@"shiftAmount"] floatValue] : 2.0;
    _interval = prefs[@"shiftInterval"] ? [prefs[@"shiftInterval"] doubleValue] : 120.0;

    // Safety floors so a bad pref value can't spin the timer or shift the UI too far
    if (_interval < 15.0) _interval = 15.0;
    if (_amount > 4.0) _amount = 4.0;
    if (_amount < 0.5) _amount = 0.5;
}

- (void)start {
    if (!_enabled) return;
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:_interval
                                               target:self
                                             selector:@selector(performShift)
                                             userInfo:nil
                                              repeats:YES];
}

- (void)stop {
    [_timer invalidate];
    _timer = nil;
}

- (void)performShift {
    if (!_enabled) return;

    _phase = (_phase + 1) % 4;
    CGFloat dx = 0, dy = 0;
    switch (_phase) {
        case 0: dx =  _amount; dy =  0;        break;
        case 1: dx =  0;       dy =  _amount;  break;
        case 2: dx = -_amount; dy =  0;        break;
        case 3: dx =  0;       dy = -_amount;  break;
    }

    for (UIWindow *window in [self chromeWindows]) {
        [UIView animateWithDuration:1.0
                          animations:^{
            window.transform = CGAffineTransformMakeTranslation(dx, dy);
        }];
    }
}

// Only shift SpringBoard's persistent chrome (status bar / dock), never
// windows belonging to foreground app content.
- (NSArray<UIWindow *> *)chromeWindows {
    NSMutableArray *windows = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        NSString *className = NSStringFromClass([window class]);
        if ([className containsString:@"StatusBar"] ||
            [className containsString:@"Dock"]) {
            [windows addObject:window];
        }
    }
    return windows;
}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    // Give SpringBoard a few seconds to finish standing up its windows
    // before we start touching them.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        [[PixelShiftManager sharedManager] start];
    });
}

%end

%ctor {
    %init;
}

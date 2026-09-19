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
            PrefsChangedCallback,
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
    NSDictionary *prefs = nil;
    @try {
        prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    } @catch (__unused NSException *exception) {
        prefs = nil;
    }

    // IMPORTANT: defaults to OFF. The person has to explicitly enable this
    // in Settings > PixelShift after confirming the tweak installed cleanly.
    _enabled  = prefs[@"enabled"]       ? [prefs[@"enabled"] boolValue]       : NO;
    _amount   = prefs[@"shiftAmount"]   ? [prefs[@"shiftAmount"] floatValue]  : 2.0;
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

    @try {
        _phase = (_phase + 1) % 4;
        CGFloat dx = 0, dy = 0;
        switch (_phase) {
            case 0: dx =  _amount; dy =  0;        break;
            case 1: dx =  0;       dy =  _amount;  break;
            case 2: dx = -_amount; dy =  0;        break;
            case 3: dx =  0;       dy = -_amount;  break;
        }

        NSArray<UIWindow *> *targets = [self chromeWindows];
        for (UIWindow *window in targets) {
            if (![window isKindOfClass:[UIWindow class]]) continue;
            __weak UIWindow *weakWindow = window;
            [UIView animateWithDuration:1.0
                              animations:^{
                UIWindow *strongWindow = weakWindow;
                if (!strongWindow) return;
                strongWindow.transform = CGAffineTransformMakeTranslation(dx, dy);
            }];
        }
    } @catch (NSException *exception) {
        // Never let a shift attempt take SpringBoard down with it — worst
        // case is this cycle silently does nothing.
        [self stop];
    }
}

// Only shift SpringBoard's persistent chrome (status bar / dock), never
// windows belonging to foreground app content.
- (NSArray<UIWindow *> *)chromeWindows {
    NSMutableArray *windows = [NSMutableArray array];

    @try {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            NSArray<UIWindow *> *sceneWindows = windowScene.windows;
            if (![sceneWindows isKindOfClass:[NSArray class]]) continue;

            for (UIWindow *window in sceneWindows) {
                if (![window isKindOfClass:[UIWindow class]]) continue;
                NSString *className = NSStringFromClass([window class]);
                if ([className containsString:@"StatusBar"] ||
                    [className containsString:@"Dock"]) {
                    [windows addObject:window];
                }
            }
        }
    } @catch (__unused NSException *exception) {
        return @[];
    }

    return windows;
}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    // Give SpringBoard plenty of time to finish standing up its windows
    // and scenes before we ever touch them.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        [[PixelShiftManager sharedManager] start];
    });
}

%end

%ctor {
    %init;
}

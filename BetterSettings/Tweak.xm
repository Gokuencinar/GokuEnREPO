#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const BSDomain = @"com.gokuencinar.bettersettings";
static NSString *const BSGroupItemsKey = @"BetterSettingsGroupItems";
static char BSOriginalBackgroundKey, BSOriginalSeparatorKey, BSGroupingBusyKey;
static char BSOriginalSpecifiersKey, BSLastGroupingConfigKey;
static char BSOriginalCellColorKey, BSOriginalContentColorKey, BSOriginalCellConfigurationKey;
static char BSCellStyledKey;
static NSUInteger BSDiagnosticCount;
static BOOL BSBoolean(NSString *key, BOOL fallback);

// Bounded device diagnostics, without collecting preference names, bundle IDs,
// phone data or tweak titles. Useful for verifying iOS 18's actual controllers.
static void BSDiagnostic(NSString *stage, id controller, NSUInteger count) {
    if (BSDiagnosticCount++ >= 24) return;
    CFStringRef domain = (__bridge CFStringRef)BSDomain;
    // Always record the constructor even if Preferences cannot read the
    // switch: otherwise lack of a record cannot distinguish injection failure.
    BOOL enabledHere = BSBoolean(@"enabled", NO);
    CFPreferencesSetAppValue(CFSTR("diagStage"), (__bridge CFStringRef)stage, domain);
    CFPreferencesSetAppValue(CFSTR("diagClass"), (__bridge CFStringRef)
        (controller ? NSStringFromClass([controller class]) : @"startup"), domain);
    CFPreferencesSetAppValue(CFSTR("diagSpecifierCount"), (__bridge CFPropertyListRef)@(count), domain);
    CFPreferencesSetAppValue(CFSTR("diagHookCalls"), (__bridge CFPropertyListRef)@(BSDiagnosticCount), domain);
    CFPreferencesSetAppValue(CFSTR("diagEnabledSeen"), enabledHere ? kCFBooleanTrue : kCFBooleanFalse, domain);
    CFPreferencesAppSynchronize(domain);
}

static id BSValue(NSString *key, id fallback) {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
        (__bridge CFStringRef)BSDomain));
    return value ?: fallback;
}

static BOOL BSBoolean(NSString *key, BOOL fallback) {
    id value = BSValue(key, @(fallback));
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static NSString *BSString(NSString *key, NSString *fallback) {
    id value = BSValue(key, fallback);
    return [value isKindOfClass:[NSString class]] && [value length] ? value : fallback;
}

static UIColor *BSColor(NSString *key, NSString *fallback) {
    NSString *s = BSString(key, fallback);
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    if (s.length != 7 || ![s hasPrefix:@"#"] ||
        [[s substringFromIndex:1] rangeOfCharacterFromSet:[hex invertedSet]].location != NSNotFound) {
        s = fallback;
    }
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:[s substringFromIndex:1]] scanHexInt:&rgb];
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
        green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1];
}

static NSString *BSBackgroundPath(void) {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return [[library stringByAppendingPathComponent:@"Preferences"]
        stringByAppendingPathComponent:@"com.gokuencinar.bettersettings-background.jpg"];
}

static BOOL BSIsRootController(UIViewController *controller) {
    if (!controller || !controller.isViewLoaded) return NO;
    UINavigationController *nav = controller.navigationController;
    if (nav.viewControllers.count && nav.viewControllers.firstObject == controller) return YES;
    // Some versions of Settings place the root list below a dedicated wrapper.
    UIViewController *parent = controller.parentViewController;
    return parent && [NSStringFromClass(parent.class) isEqualToString:@"PSUIPrefsRootController"];
}

@interface BSGradientView : UIView
@property (nonatomic, strong) UIColor *top;
@property (nonatomic, strong) UIColor *bottom;
@end

@implementation BSGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.top || !self.bottom) return;
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    layer.colors = @[(__bridge id)self.top.CGColor, (__bridge id)self.bottom.CGColor];
    layer.startPoint = CGPointMake(0.5, 0);
    layer.endPoint = CGPointMake(0.5, 1);
}
@end

// This controller shows the original preference specifiers. Loading and
// navigation need physical testing with PreferenceLoader on iOS 18.
@interface BSGroupedListController : PSListController
@end

@implementation BSGroupedListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSArray *items = [self.specifier propertyForKey:BSGroupItemsKey];
        NSMutableArray *groupItems = [[NSMutableArray alloc] initWithObjects:[PSSpecifier emptyGroupSpecifier], nil];
        if ([items isKindOfClass:[NSArray class]]) [groupItems addObjectsFromArray:items];
        _specifiers = groupItems;
    }
    return _specifiers;
}
@end

static NSArray *BSGroupedSpecifiers(NSArray *original, PSListController *controller) {
    if (!BSBoolean(@"enabled", NO) || !BSBoolean(@"groupTweaks", YES) || original.count == 0) return original;
    // PreferenceLoader 2.2.8 stamps its own rows with pl_bundle. It does NOT
    // use the PREFERENCELOADER_GROUP ID found in some third-party forks.
    NSMutableIndexSet *tweakIndexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < original.count; ++i) {
        PSSpecifier *s = original[i];
        if ([[s propertyForKey:@"id"] isEqual:@"BS_SETTINGS18_GROUP"]) return original;
        if (s.cellType != PSGroupCell && [[s propertyForKey:@"pl_bundle"] isKindOfClass:[NSBundle class]])
            [tweakIndexes addIndex:i];
    }
    if (!tweakIndexes.count) {
        BSDiagnostic(@"no-pl-bundle", controller, original.count);
        return original;
    }
    // PreferenceLoader adds an *unnamed group* followed by its consecutive
    // rows. Some PSBundleController entries have no pl_bundle property: use
    // the identifiable entries only as anchors and take the complete group.
    NSUInteger firstIndex = tweakIndexes.firstIndex;
    if (firstIndex == 0) {
        BSDiagnostic(@"first-index-zero", controller, original.count);
        return original;
    }
    NSUInteger headerIndex = NSNotFound;
    for (NSUInteger i = firstIndex; i > 0; --i) {
        PSSpecifier *candidate = original[i - 1];
        if (candidate.cellType == PSGroupCell) { headerIndex = i - 1; break; }
    }
    if (headerIndex == NSNotFound || ((PSSpecifier *)original[headerIndex]).name.length != 0) {
        BSDiagnostic(@"missing-pl-header", controller, original.count);
        return original;
    }
    NSUInteger endIndex = original.count;
    for (NSUInteger i = headerIndex + 1; i < original.count; ++i) {
        if (((PSSpecifier *)original[i]).cellType == PSGroupCell) { endIndex = i; break; }
    }
    if (endIndex <= headerIndex + 1 || tweakIndexes.lastIndex >= endIndex) {
        BSDiagnostic(@"invalid-pl-section", controller, original.count);
        return original;
    }

    NSMutableArray *items = [NSMutableArray new];
    for (NSUInteger i = headerIndex + 1; i < endIndex; ++i) [items addObject:original[i]];

    if (BSBoolean(@"alphabetizeTweaks", YES)) {
        [items sortUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
            return [(a.name ?: @"") localizedStandardCompare:(b.name ?: @"")];
        }];
    }

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:BSString(@"tweaksTitle", @"Mis tweaks")
        target:controller set:NULL get:NULL detail:[BSGroupedListController class]
        cell:PSLinkCell edit:nil];
    [group setProperty:items forKey:BSGroupItemsKey];
    [group setProperty:@"BS_SETTINGS18_GROUP" forKey:@"id"];
    [group setProperty:@YES forKey:@"enabled"];
    NSMutableArray *result = [original mutableCopy];
    // Preserve the source group marker. Replacing only its rows keeps every
    // other Settings group/index untouched.
    [result removeObjectsInRange:NSMakeRange(headerIndex + 1, endIndex - headerIndex - 1)];
    NSUInteger insertion = headerIndex + 1;
    if (BSBoolean(@"groupAtTop", NO)) {
        insertion = (result.count > 0 && ((PSSpecifier *)result[0]).cellType == PSGroupCell) ? 1 : 0;
    }
    [result insertObject:group atIndex:insertion];
    BSDiagnostic(@"group-built", controller, result.count);
    return result;
}

static void BSApplyGrouping(id controller) {
    // The SwiftUI root on iOS 18 is handled by the dedicated PreferenceLoader
    // root integration. Do not create an additional group in General.
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18) return;
    if (objc_getAssociatedObject(controller, &BSGroupingBusyKey) ||
        ![controller respondsToSelector:@selector(setSpecifiers:)] ||
        ![controller respondsToSelector:@selector(specifiers)]) return;
    NSArray *current = [controller specifiers];
    BOOL containsOurLink = NO;
    for (PSSpecifier *s in current) {
        if ([[s propertyForKey:@"id"] isEqual:@"BS_SETTINGS18_GROUP"]) { containsOurLink = YES; break; }
    }
    NSArray *original = objc_getAssociatedObject(controller, &BSOriginalSpecifiersKey);
    if (!original || !containsOurLink) {
        original = [current copy];
        objc_setAssociatedObject(controller, &BSOriginalSpecifiersKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL enabled = BSBoolean(@"enabled", NO) && BSBoolean(@"groupTweaks", YES);
    NSString *configuration = [NSString stringWithFormat:@"%d:%d:%@",
        enabled, BSBoolean(@"alphabetizeTweaks", YES), BSString(@"tweaksTitle", @"Mis tweaks")];
    configuration = [configuration stringByAppendingFormat:@":%d", BSBoolean(@"groupAtTop", NO)];
    NSString *lastConfiguration = objc_getAssociatedObject(controller, &BSLastGroupingConfigKey);
    if ([configuration isEqualToString:lastConfiguration] && (containsOurLink == enabled)) return;
    NSArray *grouped = enabled ? BSGroupedSpecifiers(original, controller) : original;
    if (grouped == original && !containsOurLink) {
        objc_setAssociatedObject(controller, &BSLastGroupingConfigKey, configuration, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }
    objc_setAssociatedObject(controller, &BSGroupingBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [controller setSpecifiers:[grouped mutableCopy]];
    objc_setAssociatedObject(controller, &BSGroupingBusyKey, nil, OBJC_ASSOCIATION_ASSIGN);
    BSDiagnostic(@"group-applied", controller, grouped.count);
    objc_setAssociatedObject(controller, &BSLastGroupingConfigKey, configuration, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// The Settings root is SwiftUI on iOS 18. Its list does not use this
// PSListController's UITableView. Apply appearance only to the real UIKit
// pages we own or to PreferenceLoader's grouped tweak destination.
static BOOL BSCanStyleController(id controller) {
    NSString *name = NSStringFromClass([controller class]);
    if ([name isEqualToString:@"PLEntryPaneController"] ||
        [name isEqualToString:@"BSGroupedListController"] ||
        [name isEqualToString:@"BetterRootListController"] ||
        [name isEqualToString:@"BSOrganizationListController"] ||
        [name isEqualToString:@"BSAppearanceListController"] ||
        [name isEqualToString:@"BSStatusListController"]) return YES;
    if (@available(iOS 18.0, *)) return NO;
    return BSIsRootController(controller);
}

static UITableView *BSTableForController(id controller) {
    if (!BSCanStyleController(controller) || ![controller isViewLoaded]) return nil;
    SEL tableSelector = [controller respondsToSelector:@selector(tableView)] ?
        @selector(tableView) : ([controller respondsToSelector:@selector(table)] ? @selector(table) : NULL);
    if (!tableSelector) return nil;
    UITableView *(*getTable)(id, SEL) = (UITableView *(*)(id, SEL))objc_msgSend;
    UITableView *table = getTable(controller, tableSelector);
    return [table isKindOfClass:[UITableView class]] ? table : nil;
}

static void BSStyleVisibleCells(UITableView *table) {
    BOOL enabled = BSBoolean(@"appearanceEnabled", NO);
    BOOL hasBackground = enabled && (BSBoolean(@"gradientEnabled", YES) ||
        BSBoolean(@"backgroundImageEnabled", NO));
    for (UITableViewCell *cell in table.visibleCells) {
        NSNumber *applied = objc_getAssociatedObject(cell, &BSCellStyledKey);
        if (applied && applied.boolValue == hasBackground) continue;
        if (!objc_getAssociatedObject(cell, &BSOriginalCellColorKey)) {
            objc_setAssociatedObject(cell, &BSOriginalCellColorKey,
                cell.backgroundColor ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(cell, &BSOriginalContentColorKey,
                cell.contentView.backgroundColor ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (@available(iOS 14.0, *))
                objc_setAssociatedObject(cell, &BSOriginalCellConfigurationKey,
                    cell.backgroundConfiguration ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        id originalCell = objc_getAssociatedObject(cell, &BSOriginalCellColorKey);
        id originalContent = objc_getAssociatedObject(cell, &BSOriginalContentColorKey);
        if (hasBackground) {
            // A translucent system surface preserves readable controls over a photo.
            cell.backgroundColor = [[UIColor secondarySystemGroupedBackgroundColor] colorWithAlphaComponent:0.82];
            cell.contentView.backgroundColor = UIColor.clearColor;
            if (@available(iOS 14.0, *)) {
                UIBackgroundConfiguration *config = [UIBackgroundConfiguration clearConfiguration];
                config.backgroundColor = [[UIColor secondarySystemGroupedBackgroundColor] colorWithAlphaComponent:0.82];
                cell.backgroundConfiguration = config;
            }
        } else {
            cell.backgroundColor = originalCell == [NSNull null] ? nil : originalCell;
            cell.contentView.backgroundColor = originalContent == [NSNull null] ? nil : originalContent;
            if (@available(iOS 14.0, *)) {
                id originalConfig = objc_getAssociatedObject(cell, &BSOriginalCellConfigurationKey);
                cell.backgroundConfiguration = originalConfig == [NSNull null] ? nil : originalConfig;
            }
        }
        objc_setAssociatedObject(cell, &BSCellStyledKey, @(hasBackground), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void BSApplyAppearance(id controller) {
    UITableView *table = BSTableForController(controller);
    if (!table) return;

    if (!objc_getAssociatedObject(table, &BSOriginalSeparatorKey)) {
        objc_setAssociatedObject(table, &BSOriginalSeparatorKey, @(table.separatorStyle + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(table, &BSOriginalBackgroundKey, table.backgroundView ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL enabled = BSBoolean(@"appearanceEnabled", NO);
    BOOL gradient = enabled && BSBoolean(@"gradientEnabled", YES);
    BOOL useImage = enabled && BSBoolean(@"backgroundImageEnabled", NO);
    BOOL hideSeparators = enabled && BSBoolean(@"hideSeparators", NO);
    table.separatorStyle = (UITableViewCellSeparatorStyle)(hideSeparators ? UITableViewCellSeparatorStyleNone :
        ([objc_getAssociatedObject(table, &BSOriginalSeparatorKey) integerValue] - 1));

    UIImage *image = useImage ? [UIImage imageWithContentsOfFile:BSBackgroundPath()] : nil;
    if (image) {
        UIView *background = [[UIView alloc] initWithFrame:table.bounds];
        background.clipsToBounds = YES;
        background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:background.bounds];
        imageView.image = image;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:imageView];
        if (BSBoolean(@"backgroundBlurEnabled", NO) && !UIAccessibilityIsReduceTransparencyEnabled()) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
                [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
            blur.frame = background.bounds;
            blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [background addSubview:blur];
        }
        table.backgroundView = background;
    } else if (gradient) {
        BSGradientView *view = [[BSGradientView alloc] initWithFrame:table.bounds];
        view.top = BSColor(@"gradientTop", @"#15263A");
        view.bottom = BSColor(@"gradientBottom", @"#536A85");
        table.backgroundView = view;
    } else {
        id original = objc_getAssociatedObject(table, &BSOriginalBackgroundKey);
        table.backgroundView = original == [NSNull null] ? nil : original;
    }
    BSStyleVisibleCells(table);
}

%group AppearancePages
%hook PSListController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (BSCanStyleController(self)) BSApplyAppearance(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    UITableView *table = BSTableForController(self);
    if (table) BSStyleVisibleCells(table);
}
%end
%end

// Use the same runtime target selection as PreferenceLoader 2.2.8. On iOS 18
// the only preloaded target is often PSGGeneralController, not either root class.
%group SettingsHost
%hook PrefsListController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    BSDiagnostic(@"host-view", self, 0);
    BSApplyGrouping(self);
    BSApplyAppearance(self);
}
%end
%end

%ctor {
    @autoreleasepool {
        Class modern = objc_getClass("PSUIPrefsListController");
        Class legacy = objc_getClass("PrefsListController");
        Class general = objc_getClass("PSGGeneralController");
        Class host = modern ?: legacy ?: general;
        BSDiagnostic([NSString stringWithFormat:@"ctor-m%d-l%d-g%d-h%d-v%d-s%d-w%d",
            modern != Nil, legacy != Nil, general != Nil, host != Nil,
            host && class_getInstanceMethod(host, @selector(viewWillAppear:)) != NULL,
            host && class_getInstanceMethod(host, @selector(specifiers)) != NULL,
            host && class_getInstanceMethod(host, @selector(setSpecifiers:)) != NULL], nil, 0);
        if (host && class_getInstanceMethod(host, @selector(viewWillAppear:))) {
            %init(SettingsHost, PrefsListController = host);
        }
        Class list = objc_getClass("PSListController");
        if (list && class_getInstanceMethod(list, @selector(viewWillAppear:)) &&
            class_getInstanceMethod(list, @selector(viewDidLayoutSubviews))) {
            %init(AppearancePages);
        }
    }
}

#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <PhotosUI/PhotosUI.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <math.h>

static CFStringRef const COSDomain = CFSTR("com.gokuencinar.cossettings18");
static NSString *const COSChangedNotification = @"com.gokuencinar.cossettings18/preferences-changed";

static id COSRead(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, COSDomain));
}

static BOOL COSReadBool(NSString *key, BOOL defaultValue) {
    id value = COSRead(key);
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : defaultValue;
}

static void COSWrite(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, COSDomain);
}

static void COSCommit(void) {
    CFPreferencesAppSynchronize(COSDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)COSChangedNotification, NULL, NULL, YES);
}

static NSString *COSValidatedHex(NSString *text) {
    if (![text isKindOfClass:[NSString class]]) return nil;
    NSString *s = [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (s.length != 7 || ![s hasPrefix:@"#"]) return nil;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    return [[s substringFromIndex:1] rangeOfCharacterFromSet:invalid].location == NSNotFound ? s : nil;
}

static UIColor *COSColor(NSString *key, NSString *fallback) {
    NSString *s = COSValidatedHex(COSRead(key)) ?: fallback;
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:[s substringFromIndex:1]] scanHexInt:&rgb];
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
        green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1];
}

static NSString *COSBackgroundPath(void) {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return [[library stringByAppendingPathComponent:@"Preferences"]
        stringByAppendingPathComponent:@"com.gokuencinar.cossettings18-background.jpg"];
}

// The preview belongs to COS Settings' own panel. It does not depend on an
// unverified iOS 18 Settings-root hook and never touches Apple's views.
@interface COSBannerView : UIView
@property (nonatomic) BOOL appearancePreview;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *subtitle;
@property (nonatomic, strong) UILabel *caption;
@property (nonatomic, strong) UIView *swatch;
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, strong) UIImageView *photo;
- (void)refresh;
@end

@implementation COSBannerView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        _card = [UIView new];
        _card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        _card.layer.cornerRadius = 17;
        [self addSubview:_card];
        _iconView = [UIImageView new];
        _iconView.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
        _iconView.tintColor = UIColor.whiteColor;
        _iconView.contentMode = UIViewContentModeCenter;
        _iconView.backgroundColor = UIColor.systemIndigoColor;
        _iconView.layer.cornerRadius = 12;
        _iconView.clipsToBounds = YES;
        [_card addSubview:_iconView];
        _heading = [UILabel new];
        _heading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _heading.adjustsFontForContentSizeCategory = YES;
        _heading.textColor = UIColor.labelColor;
        [_card addSubview:_heading];
        _subtitle = [UILabel new];
        _subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        _subtitle.adjustsFontForContentSizeCategory = YES;
        _subtitle.textColor = UIColor.secondaryLabelColor;
        _subtitle.numberOfLines = 2;
        [_card addSubview:_subtitle];
        _caption = [UILabel new];
        _caption.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _caption.adjustsFontForContentSizeCategory = YES;
        _caption.textColor = UIColor.secondaryLabelColor;
        _caption.numberOfLines = 2;
        [_card addSubview:_caption];
        _swatch = [UIView new];
        _swatch.clipsToBounds = YES;
        _swatch.layer.cornerRadius = 11;
        [_card addSubview:_swatch];
        _gradient = [CAGradientLayer layer];
        [_swatch.layer addSublayer:_gradient];
        _photo = [UIImageView new];
        _photo.contentMode = UIViewContentModeScaleAspectFill;
        _photo.clipsToBounds = YES;
        [_swatch addSubview:_photo];
        self.isAccessibilityElement = YES;
    }
    return self;
}

- (void)refresh {
    if (self.appearancePreview) {
        self.heading.text = @"Vista previa";
        self.subtitle.text = @"Imagen o degradado elegido";
        self.iconView.image = [UIImage systemImageNamed:@"paintpalette.fill"];
        self.gradient.colors = @[(__bridge id)COSColor(@"gradientTop", @"#15263A").CGColor,
            (__bridge id)COSColor(@"gradientBottom", @"#536A85").CGColor];
        self.gradient.startPoint = CGPointMake(0.5, 0);
        self.gradient.endPoint = CGPointMake(0.5, 1);
        BOOL usePhoto = COSReadBool(@"backgroundImageEnabled", NO);
        UIImage *image = usePhoto ? [UIImage imageWithContentsOfFile:COSBackgroundPath()] : nil;
        self.photo.image = image;
        self.caption.text = image ? @"IMAGEN SELECCIONADA" : @"DEGRADADO PERSONALIZADO";
        if (!COSReadBool(@"appearanceEnabled", NO)) self.caption.text = @"VISTA PREVIA · APARIENCIA DESACTIVADA";
        self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", self.heading.text, self.caption.text];
    } else {
        self.heading.text = @"COS Settings 18";
        self.subtitle.text = @"Organiza y personaliza tus Ajustes";
        self.caption.text = COSReadBool(@"enabled", NO)
            ? @"CATEGORÍA TWEAKS ACTIVADA · BETA iOS 18" : @"CATEGORÍA TWEAKS DESACTIVADA · BETA iOS 18";
        self.iconView.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
        self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", self.heading.text, self.caption.text];
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = CGRectGetWidth(self.bounds);
    self.card.frame = CGRectMake(16, 10, MAX(w - 32, 0), MAX(CGRectGetHeight(self.bounds) - 20, 0));
    CGFloat innerW = CGRectGetWidth(self.card.bounds);
    self.iconView.frame = CGRectMake(16, 16, 44, 44);
    self.heading.frame = CGRectMake(72, 15, MAX(innerW - 88, 0), 29);
    self.subtitle.frame = CGRectMake(72, 43, MAX(innerW - 88, 0), 42);
    if (self.appearancePreview) {
        self.swatch.hidden = NO;
        self.swatch.frame = CGRectMake(16, 89, MAX(innerW - 32, 0), 82);
        self.gradient.frame = self.swatch.bounds;
        self.photo.frame = self.swatch.bounds;
        self.caption.frame = CGRectMake(17, 175, MAX(innerW - 34, 0), 25);
    } else {
        self.swatch.hidden = YES;
        self.caption.frame = CGRectMake(16, 94, MAX(innerW - 32, 0), 34);
    }
}
@end

@interface COSSettingsBaseController : PSListController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) COSBannerView *cosBanner;
- (void)refreshBanner;
- (void)showError:(NSString *)message;
@end

@interface COSRootListController : COSSettingsBaseController @end
@interface COSOrganizationListController : COSSettingsBaseController @end
@interface COSAppearanceListController : COSSettingsBaseController @end
@interface COSStatusListController : COSSettingsBaseController @end

static PSSpecifier *COSGroup(NSString *name, NSString *footer) {
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:name];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

static PSSpecifier *COSLink(NSString *name, NSString *identifier, Class controller, id target) {
    PSSpecifier *link = [PSSpecifier preferenceSpecifierNamed:name target:target
        set:NULL get:NULL detail:controller cell:PSLinkCell edit:nil];
    [link setProperty:identifier forKey:@"id"];
    [link setProperty:@YES forKey:@"enabled"];
    NSString *symbol = [identifier isEqualToString:@"cos.organize"] ? @"square.grid.2x2.fill" :
        ([identifier isEqualToString:@"cos.appearance"] ? @"paintpalette.fill" : @"info.circle.fill");
    UIImage *icon = [UIImage systemImageNamed:symbol];
    if (icon) [link setProperty:icon forKey:@"iconImage"];
    return link;
}

// Root.plist remains the single source of the 12 runtime preference keys.
// Split its existing sections when presenting the two settings pages.
static NSMutableArray *COSSettingsSection(PSListController *controller, BOOL appearance) {
    NSArray *all = [controller loadSpecifiersFromPlistName:@"Root" target:controller];
    NSMutableArray *selection = [NSMutableArray array];
    BOOL collecting = !appearance;
    for (PSSpecifier *item in all) {
        if (item.cellType == PSGroupCell && [item.name isEqualToString:@"APARIENCIA"]) {
            if (!appearance) break;
            collecting = YES;
        }
        if (appearance && item.cellType == PSGroupCell && [item.name isEqualToString:@"ACERCA DE"]) break;
        if (collecting) [selection addObject:item];
    }
    return selection;
}

@implementation COSSettingsBaseController
- (void)viewDidLoad {
    [super viewDidLoad];
    if (![self isKindOfClass:[COSRootListController class]] &&
        ![self isKindOfClass:[COSAppearanceListController class]]) return;
    if (![self respondsToSelector:@selector(tableView)]) return;
    UITableView *table = self.tableView;
    if (![table isKindOfClass:[UITableView class]]) return;
    BOOL appearance = [self isKindOfClass:[COSAppearanceListController class]];
    self.cosBanner = [[COSBannerView alloc] initWithFrame:CGRectMake(0, 0,
        CGRectGetWidth(table.bounds), appearance ? 225 : 155)];
    self.cosBanner.appearancePreview = appearance;
    [self refreshBanner];
    table.tableHeaderView = self.cosBanner;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshBanner];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.cosBanner) return;
    UITableView *table = self.tableView;
    CGFloat width = CGRectGetWidth(table.bounds);
    if (fabs(CGRectGetWidth(self.cosBanner.frame) - width) > 1.0) {
        CGRect frame = self.cosBanner.frame;
        frame.size.width = width;
        self.cosBanner.frame = frame;
        table.tableHeaderView = self.cosBanner;
    }
}

- (void)refreshBanner {
    [self.cosBanner refresh];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:[NSString class]]) return nil;
    id saved = COSRead(key);
    return saved ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:[NSString class]] || !value) return;
    if ([key isEqualToString:@"gradientTop"] || [key isEqualToString:@"gradientBottom"]) {
        NSString *hex = COSValidatedHex(value);
        if (!hex) {
            [self showError:@"Escribe un color hexadecimal de seis cifras, por ejemplo #15263A."];
            [self reloadSpecifier:specifier];
            return;
        }
        value = hex;
    }
    COSWrite(key, value);
    COSCommit();
    [self refreshBanner];
}

- (void)showError:(NSString *)message {
    if (!self.view.window) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"COS Settings"
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyPaletteTop:(NSString *)top bottom:(NSString *)bottom {
    COSWrite(@"gradientTop", top);
    COSWrite(@"gradientBottom", bottom);
    COSWrite(@"gradientEnabled", @YES);
    COSWrite(@"backgroundImageEnabled", @NO);
    COSCommit();
    [self reloadSpecifiers];
    [self refreshBanner];
}

- (void)applyOceanPreset {
    [self applyPaletteTop:@"#15263A" bottom:@"#536A85"];
}

- (void)applyGraphitePreset {
    [self applyPaletteTop:@"#181B22" bottom:@"#626B7A"];
}

- (void)chooseBackground {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (!results.count) return; // User cancelled.
    if (![provider canLoadObjectOfClass:[UIImage class]]) {
        [self showError:@"El formato de esta imagen no es compatible."];
        return;
    }
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || ![object isKindOfClass:[UIImage class]]) {
                [self showError:@"No se pudo cargar la imagen de Fotos."];
                return;
            }
            UIImage *photo = (UIImage *)object;
            CGFloat maxSide = MAX(photo.size.width, photo.size.height);
            if (!isfinite(maxSide) || maxSide <= 0 || !isfinite(photo.size.width) || !isfinite(photo.size.height)) {
                [self showError:@"La imagen tiene dimensiones no válidas."];
                return;
            }
            CGFloat scale = MIN(1600.0 / maxSide, 1.0);
            CGSize size = CGSizeMake(photo.size.width * scale, photo.size.height * scale);
            UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
            [photo drawInRect:(CGRect){CGPointZero, size}];
            UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSData *jpeg = scaled ? UIImageJPEGRepresentation(scaled, 0.85) : nil;
            if (!jpeg || jpeg.length > 8000000 || ![jpeg writeToFile:COSBackgroundPath() atomically:YES]) {
                [self showError:@"No se pudo guardar la imagen. Prueba otra foto."];
                return;
            }
            COSWrite(@"backgroundImageEnabled", @YES);
            COSWrite(@"appearanceEnabled", @YES);
            COSCommit();
            [self reloadSpecifiers];
            [self refreshBanner];
        });
    }];
}

- (void)clearBackground {
    NSString *path = COSBackgroundPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
            [self showError:@"No se pudo eliminar la imagen seleccionada."];
            return;
        }
    }
    COSWrite(@"backgroundImageEnabled", @NO);
    COSCommit();
    [self reloadSpecifiers];
    [self refreshBanner];
}
@end

@implementation COSRootListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"COS Settings 18";
}
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray arrayWithObjects:
            COSGroup(@"COS SETTINGS", @"Configura cada función desde su propia pantalla."),
            COSLink(@"Organización", @"cos.organize", [COSOrganizationListController class], self),
            COSLink(@"Apariencia", @"cos.appearance", [COSAppearanceListController class], self),
            COSGroup(@"INFORMACIÓN", @"COS Settings 18 · Beta experimental para iOS 18. La categoría Tweaks aparece en la pantalla principal con el motor COS PreferenceLoader."),
            COSLink(@"Estado y compatibilidad", @"cos.status", [COSStatusListController class], self), nil];
    }
    return _specifiers;
}
@end

@implementation COSOrganizationListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Organización";
}
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = COSSettingsSection(self, NO);
    return _specifiers;
}
@end

@implementation COSAppearanceListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Apariencia";
}
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = COSSettingsSection(self, YES);
    return _specifiers;
}
@end

@implementation COSStatusListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Estado";
}
- (NSArray *)specifiers {
    if (!_specifiers) {
        BOOL active = COSReadBool(@"enabled", NO) && COSReadBool(@"groupTweaks", YES);
        NSString *stage = COSRead(@"diagStage");
        NSString *host = COSRead(@"diagClass");
        id count = COSRead(@"diagSpecifierCount");
        BOOL found = [stage isKindOfClass:[NSString class]] && stage.length;
        NSString *detail = found ? [NSString stringWithFormat:@"Última etapa: %@. Controlador: %@. Specifiers observados: %@.",
            stage, [host isKindOfClass:[NSString class]] ? host : @"desconocido",
            [count respondsToSelector:@selector(stringValue)] ? [count stringValue] : @"sin datos"]
            : @"Aún no hay diagnóstico. Abre Ajustes > General y vuelve a esta pantalla.";
        _specifiers = [NSMutableArray arrayWithObjects:
            COSGroup(@"ORGANIZACIÓN", active ? @"La organización está activada en las preferencias." : @"La organización está desactivada en las preferencias."),
            COSGroup(@"DIAGNÓSTICO DEL HOOK", detail),
            COSGroup(@"COMPATIBILIDAD", @"COS PreferenceLoader experimental coloca Tweaks en la portada SwiftUI de Ajustes. Los ajustes de organización se aplican al volver a abrir Ajustes. Las opciones visuales muestran una vista previa local; su efecto sobre el fondo de la portada no está verificado."),
            COSGroup(@"AYUDA", @"Después de cambiar la organización, cierra Ajustes desde el selector de aplicaciones y vuelve a abrirlo. Comprueba los accesos a los tweaks antes de activar modificaciones adicionales."), nil];
    }
    return _specifiers;
}
@end

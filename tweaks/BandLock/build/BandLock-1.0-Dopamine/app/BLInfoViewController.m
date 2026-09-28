#import "BLInfoViewController.h"
#import "BLFrequencyGlossaryViewController.h"
#import "BLCCPreferences.h"
#import "BLLocalization.h"
#import "BLCommon.h"

static NSString * const BLRepositoryURL = @"https://github.com/Gokuencinar/GokuEnREPO";
static NSString * const BLBuyMeACoffeeURL = @"https://buymeacoffee.com/gokuen";
static NSString * const BLPackagesURL = @"https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/Packages";
static NSString * const BLChangelogRawURL = @"https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/tweaks/BandLock/CHANGELOG.md";
#if BL_VARIANT_ROOTFUL
static NSString * const BLPackageIdentifier = @"com.gokuencinar.bandlock.rootful";
static NSString * const BLVariantName = @"Rootful";
#else
static NSString * const BLPackageIdentifier = @"com.gokuencinar.bandlock.dopamine";
static NSString * const BLVariantName = @"Dopamine";
#endif

@interface BLReleaseNotesViewController : UIViewController
@property (nonatomic, strong) UITextView *textView;
@end


@implementation BLReleaseNotesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Notas de actualización", @"Release notes");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.alwaysBounceVertical = YES;
    self.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.textContainerInset = UIEdgeInsetsMake(18, 16, 24, 16);
    self.textView.text = BLT(@"Cargando notas de actualización…", @"Loading release notes…");
    [self.view addSubview:self.textView];
    [NSLayoutConstraint activateConstraints:@[
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.textView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self loadNotes];
}

- (void)loadNotes {
    NSURL *url = [NSURL URLWithString:BLChangelogRawURL];
    if (!url) return;
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *text = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.textView.text = text.length ? text : BLT(@"No se pudieron cargar las notas de actualización.", @"Could not load release notes.");
        });
    }] resume];
}

@end


@interface BLInfoViewController ()
@end

typedef NS_ENUM(NSInteger, BLCCSwitchTag) {
    BLCCSwitchTag2G = 20,
    BLCCSwitchTag3G,
    BLCCSwitchTagLTE,
    BLCCSwitchTag5G,
    BLCCSwitchTagAdvanced5G
};

@implementation BLInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Ajustes", @"Settings");
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 6; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 1;
    if (section == 2) return 3;
    if (section == 3) return 2;
    if (section == 4) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Centro de control · Modos visibles", @"Control Center · Visible modes");
    if (section == 1) return BLT(@"Centro de control · 5G", @"Control Center · 5G");
    if (section == 2) return BLT(@"Información", @"Info");
    if (section == 3) return BLT(@"Actualizaciones", @"Updates");
    if (section == 4) return BLT(@"Recursos", @"Resources");
    return BLT(@"Apoyar desarrollo", @"Support development");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return BLT(@"Automático siempre permanece visible para que puedas volver a la selección normal de iOS.",
                   @"Auto always remains visible so you can return to normal iOS network selection.");
    }
    if (section == 1) {
        return BLT(@"Desactivado: aparece una única opción 5G que usa 5G Auto. Activado: aparecen 5G Auto, 5G NSA y 5G SA por separado.",
                   @"Off: one 5G option is shown using 5G Auto. On: 5G Auto, 5G NSA and 5G SA are shown separately.");
    }
    return nil;
}

- (UITableViewCell *)valueCell:(NSString *)title detail:(NSString *)detail symbol:(NSString *)symbol disclosure:(BOOL)disclosure {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.imageView.image = symbol.length ? [UIImage systemImageNamed:symbol] : nil;
    cell.imageView.tintColor = UIColor.systemBlueColor;
    cell.accessoryType = disclosure ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = disclosure ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (UIImage *)creditsAvatarImage {
    NSString *avatarPath = [NSBundle.mainBundle pathForResource:@"CreditsAvatar" ofType:@"jpg"];
    UIImage *source = avatarPath.length ? [UIImage imageWithContentsOfFile:avatarPath] : nil;
    if (!source) return [UIImage systemImageNamed:@"person.crop.circle.fill"];

    CGSize size = CGSizeMake(44.0, 44.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect bounds = (CGRect){CGPointZero, size};
        [[UIBezierPath bezierPathWithOvalInRect:bounds] addClip];

        CGFloat scale = MAX(size.width / source.size.width, size.height / source.size.height);
        CGSize drawSize = CGSizeMake(source.size.width * scale, source.size.height * scale);
        CGRect drawRect = CGRectMake((size.width - drawSize.width) * 0.5,
                                     (size.height - drawSize.height) * 0.5,
                                     drawSize.width,
                                     drawSize.height);
        [source drawInRect:drawRect];
    }];
}

- (UITableViewCell *)creditsCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.imageView.image = [self creditsAvatarImage];
    cell.textLabel.text = @"Gokuencinar · GokuEn";
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = BLT(@"Créditos", @"Credits");
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title tag:(BLCCSwitchTag)tag enabled:(BOOL)enabled {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.tag = tag;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (BOOL)ccValueForTag:(BLCCSwitchTag)tag {
    switch (tag) {
        case BLCCSwitchTag2G: return BLCCShow2G();
        case BLCCSwitchTag3G: return BLCCShow3G();
        case BLCCSwitchTagLTE: return BLCCShowLTE();
        case BLCCSwitchTag5G: return BLCCShow5G();
        case BLCCSwitchTagAdvanced5G: return BLCCAdvanced5GModes();
    }
    return NO;
}

- (void)setCCValue:(BOOL)enabled forTag:(BLCCSwitchTag)tag {
    switch (tag) {
        case BLCCSwitchTag2G: BLCCSetShow2G(enabled); break;
        case BLCCSwitchTag3G: BLCCSetShow3G(enabled); break;
        case BLCCSwitchTagLTE: BLCCSetShowLTE(enabled); break;
        case BLCCSwitchTag5G: BLCCSetShow5G(enabled); break;
        case BLCCSwitchTagAdvanced5G: BLCCSetAdvanced5GModes(enabled); break;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"—";
    if (indexPath.section == 0 && indexPath.row == 0) return [self switchCellWithTitle:@"2G" tag:BLCCSwitchTag2G enabled:BLCCShow2G()];
    if (indexPath.section == 0 && indexPath.row == 1) return [self switchCellWithTitle:@"3G" tag:BLCCSwitchTag3G enabled:BLCCShow3G()];
    if (indexPath.section == 0 && indexPath.row == 2) return [self switchCellWithTitle:@"4G / LTE" tag:BLCCSwitchTagLTE enabled:BLCCShowLTE()];
    if (indexPath.section == 0) return [self switchCellWithTitle:@"5G" tag:BLCCSwitchTag5G enabled:BLCCShow5G()];
    if (indexPath.section == 1) return [self switchCellWithTitle:BLT(@"Modos 5G avanzados", @"Advanced 5G modes") tag:BLCCSwitchTagAdvanced5G enabled:BLCCAdvanced5GModes()];
    if (indexPath.section == 2 && indexPath.row == 0) return [self valueCell:@"BandLock Global" detail:BLVariantName symbol:@"antenna.radiowaves.left.and.right" disclosure:NO];
    if (indexPath.section == 2 && indexPath.row == 1) return [self valueCell:BLT(@"Versión actual", @"Current version") detail:version symbol:@"number.circle" disclosure:NO];
    if (indexPath.section == 2) return [self creditsCell];
    if (indexPath.section == 3 && indexPath.row == 0) return [self valueCell:BLT(@"Buscar actualizaciones", @"Check for updates") detail:nil symbol:@"arrow.triangle.2.circlepath" disclosure:YES];
    if (indexPath.section == 3) return [self valueCell:BLT(@"Notas de actualización", @"Release notes") detail:nil symbol:@"doc.text" disclosure:YES];
    if (indexPath.section == 4 && indexPath.row == 0) return [self valueCell:BLT(@"Visitar GokuEnREPO", @"Visit GokuEnREPO") detail:nil symbol:@"link" disclosure:YES];
    if (indexPath.section == 4) return [self valueCell:BLT(@"Más información sobre las frecuencias", @"More information about frequencies") detail:nil symbol:@"info.circle" disclosure:YES];
    return [self valueCell:@"Buy Me a Coffee" detail:nil symbol:@"heart.circle.fill" disclosure:YES];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)publishedBandLockVersionFromPackages:(NSString *)packages {
    NSString *normalized = [(packages ?: @"") stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    NSArray *stanzas = [normalized componentsSeparatedByString:@"\n\n"];
    NSString *best = nil;
    for (NSString *stanza in stanzas) {
        NSArray<NSString *> *lines = [stanza componentsSeparatedByString:@"\n"];
        NSString *packageLine = [NSString stringWithFormat:@"Package: %@", BLPackageIdentifier];
        if (![lines containsObject:packageLine]) continue;
        __block NSString *version = nil;
        [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
            if ([line hasPrefix:@"Version: "]) { version = [line substringFromIndex:9]; *stop = YES; }
        }];
        if (version.length && (!best || [version compare:best options:NSNumericSearch] == NSOrderedDescending)) best = version;
    }
    return best;
}

- (void)checkForUpdates {
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"BandLock"
                                                                      message:BLT(@"Buscando actualizaciones…", @"Checking for updates…")
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];
    NSURL *url = [NSURL URLWithString:BLPackagesURL];
    if (!url) {
        [loading dismissViewControllerAnimated:YES completion:^{ [self showMessage:BLT(@"No se pudo comprobar si hay actualizaciones.", @"Could not check for updates.")]; }];
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *raw = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSString *remote = [weakSelf publishedBandLockVersionFromPackages:raw];
        NSString *current = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
        NSString *message = nil;
        if (!remote.length || error) message = BLT(@"No se pudo comprobar si hay actualizaciones.", @"Could not check for updates.");
        else {
            NSComparisonResult comparison = [remote compare:current options:NSNumericSearch];
            if (comparison == NSOrderedDescending) {
                message = [NSString stringWithFormat:BLT(@"Hay una versión nueva disponible: %@ (instalada: %@). Abre GokuEnREPO/Sileo para actualizar.", @"A newer version is available: %@ (installed: %@). Open GokuEnREPO/Sileo to update."), remote, current];
            } else if (comparison == NSOrderedSame) {
                message = [NSString stringWithFormat:BLT(@"Estás usando la última versión publicada (%@).", @"You are using the latest published version (%@)."), current];
            } else {
                message = [NSString stringWithFormat:BLT(@"La versión instalada %@ es más reciente que la versión publicada actualmente en el repositorio %@.", @"Installed version %@ is newer than the currently published repository version %@."), current, remote];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:NO completion:^{ [weakSelf showMessage:message]; }];
        });
    }] resume];
}

- (void)openRepository {
    NSURL *url = [NSURL URLWithString:BLRepositoryURL];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)openBuyMeACoffee {
    NSURL *url = [NSURL URLWithString:BLBuyMeACoffeeURL];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 || indexPath.section == 1) {
        BLCCSwitchTag tag;
        if (indexPath.section == 1) tag = BLCCSwitchTagAdvanced5G;
        else if (indexPath.row == 0) tag = BLCCSwitchTag2G;
        else if (indexPath.row == 1) tag = BLCCSwitchTag3G;
        else if (indexPath.row == 2) tag = BLCCSwitchTagLTE;
        else tag = BLCCSwitchTag5G;
        [self setCCValue:![self ccValueForTag:tag] forTag:tag];
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    if (indexPath.section == 3 && indexPath.row == 0) { [self checkForUpdates]; return; }
    if (indexPath.section == 3 && indexPath.row == 1) {
        [self.navigationController pushViewController:[[BLReleaseNotesViewController alloc] init] animated:YES];
        return;
    }
    if (indexPath.section == 4 && indexPath.row == 0) { [self openRepository]; return; }
    if (indexPath.section == 4 && indexPath.row == 1) {
        [self.navigationController pushViewController:[[BLFrequencyGlossaryViewController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
        return;
    }
    if (indexPath.section == 5) { [self openBuyMeACoffee]; return; }
}

@end

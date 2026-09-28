#import "BLGBandSelectionController.h"
#import "BLGBandMetadata.h"
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString * const BLGStatePath = @"/var/mobile/Library/Preferences/com.gokuencinar.bandlock.state.plist";

static BOOL BLGUsesSpanish(void) {
    NSString *language = NSLocale.preferredLanguages.firstObject.lowercaseString ?: @"";
    return [language hasPrefix:@"es"];
}

static NSString *BLGT(NSString *es, NSString *en) {
    return BLGUsesSpanish() ? es : en;
}

static NSArray<NSNumber *> *BLGSortedBands(id bands) {
    if (![bands isKindOfClass:[NSArray class]] && ![bands isKindOfClass:[NSSet class]]) return @[];
    NSArray *input = [bands isKindOfClass:[NSSet class]] ? [(NSSet *)bands allObjects] : (NSArray *)bands;
    NSMutableOrderedSet *normalized = [NSMutableOrderedSet orderedSet];
    for (id item in input) {
        if ([item respondsToSelector:@selector(integerValue)]) {
            NSInteger value = [item integerValue];
            if (value > 0) [normalized addObject:@(value)];
        }
    }
    return [[normalized array] sortedArrayUsingSelector:@selector(compare:)];
}

static NSString *BLGBandList(NSArray<NSNumber *> *bands) {
    if (!bands.count) return BLGT(@"Ninguna", @"None");
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:bands.count];
    for (NSNumber *band in bands) [parts addObject:[NSString stringWithFormat:@"B%@", band]];
    return [parts componentsJoinedByString:@", "];
}

static NSMutableDictionary *BLGReadState(void) {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:BLGStatePath];
    return state ? [state mutableCopy] : [NSMutableDictionary dictionary];
}

static void BLGWriteState(NSDictionary *changes) {
    NSMutableDictionary *state = BLGReadState();
    [changes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj) state[key] = obj;
        else [state removeObjectForKey:key];
    }];
    [state writeToFile:BLGStatePath atomically:YES];
}

@interface BLGBandSelectionController () {
    NSArray<NSNumber *> *_supportedBands;
    NSArray<NSNumber *> *_activeBands;
    NSMutableSet<NSNumber *> *_selectedBands;
}
@end

@implementation BLGBandSelectionController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = BLGT(@"Bandas LTE", @"LTE Bands");
    [self reloadState];

    @try {
        UITableView *table = [self valueForKey:@"table"];
        if ([table isKindOfClass:[UITableView class]] && !table.tableHeaderView) {
            CGFloat width = CGRectGetWidth(UIScreen.mainScreen.bounds);
            UIView *outer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 116)];
            outer.backgroundColor = UIColor.clearColor;

            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 10, width - 32, 94)];
            card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
            card.layer.cornerRadius = 16.0;
            card.layer.masksToBounds = YES;
            [outer addSubview:card];

            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"slider.horizontal.3"]];
            icon.frame = CGRectMake(18, 20, 30, 30);
            icon.contentMode = UIViewContentModeScaleAspectFit;
            icon.tintColor = UIColor.systemOrangeColor;
            [card addSubview:icon];

            UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(60, 14, width - 125, 28)];
            title.text = BLGT(@"Seleccionar bandas", @"Select bands");
            title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
            title.textColor = UIColor.labelColor;
            [card addSubview:title];

            UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(60, 42, width - 125, 20)];
            subtitle.text = @"Global · LTE / 4G";
            subtitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            subtitle.textColor = UIColor.secondaryLabelColor;
            [card addSubview:subtitle];

            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 68, width - 60, 18)];
            caption.text = BLGT(@"Solo se muestran bandas que reporta el módem", @"Only modem-reported bands are shown");
            caption.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
            caption.textColor = UIColor.tertiaryLabelColor;
            [card addSubview:caption];

            table.tableHeaderView = outer;
        }
    } @catch (__unused NSException *exception) {}
}

- (void)reloadState {
    NSMutableDictionary *state = BLGReadState();
    _supportedBands = BLGSortedBands(state[@"supportedLTE"] ?: state[@"allSupportedLTE"]);
    _activeBands = BLGSortedBands(state[@"activeLTE"] ?: state[@"allActiveLTE"]);
    NSArray *pending = BLGSortedBands(state[@"pendingLTE"]);
    _selectedBands = [NSMutableSet setWithArray:(pending.count ? pending : _activeBands)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadState];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSMutableArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];

    PSSpecifier *summaryGroup = [PSSpecifier emptyGroupSpecifier];
    summaryGroup.name = BLGT(@"Selección global", @"Global selection");
    [summaryGroup setProperty:BLGT(
        @"La lista procede de las capacidades LTE que reporta tu propio módem. No se presupone un país ni un operador: que una banda sea compatible con el iPhone no significa que tu operador la despliegue en tu ubicación.",
        @"This list comes from the LTE capabilities reported by your own modem. No country or carrier is assumed: a band supported by the iPhone may still be unavailable on your carrier or at your location.") forKey:@"footerText"];
    [items addObject:summaryGroup];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Seleccionadas", @"Selected")
        target:self set:nil get:@selector(selectedValue) detail:nil cell:PSTitleValueCell edit:nil]];

    if (!_supportedBands.count) {
        PSSpecifier *empty = [PSSpecifier emptyGroupSpecifier];
        empty.name = BLGT(@"Sin datos", @"No data");
        [empty setProperty:BLGT(@"Vuelve a BandLock y pulsa «Actualizar estado» antes de entrar en esta pantalla.",
                                      @"Return to BandLock and tap “Refresh status” before opening this screen.") forKey:@"footerText"];
        [items addObject:empty];
        _specifiers = items;
        return _specifiers;
    }

    PSSpecifier *quickGroup = [PSSpecifier emptyGroupSpecifier];
    quickGroup.name = BLGT(@"Selección rápida", @"Quick selection");
    [quickGroup setProperty:BLGT(
        @"Son filtros genéricos sobre las bandas soportadas por el dispositivo; no son perfiles de operador. FDD y TDD son modos dúplex definidos por cada banda LTE.",
        @"These are generic filters over device-supported bands, not carrier profiles. FDD and TDD are duplex modes defined by each LTE band.") forKey:@"footerText"];
    [items addObject:quickGroup];

    NSArray *quick = @[
        @[BLGT(@"Selección activa actual", @"Current active selection"), NSStringFromSelector(@selector(selectCurrentActive))],
        @[BLGT(@"Todas las soportadas", @"All supported bands"), NSStringFromSelector(@selector(selectAllSupported))],
        @[BLGT(@"Solo FDD", @"FDD only"), NSStringFromSelector(@selector(selectFDD))],
        @[BLGT(@"Solo TDD", @"TDD only"), NSStringFromSelector(@selector(selectTDD))]
    ];
    for (NSArray *row in quick) {
        PSSpecifier *button = [PSSpecifier preferenceSpecifierNamed:row[0]
            target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        button.buttonAction = NSSelectorFromString(row[1]);
        [items addObject:button];
    }

    [self addBandGroup:BLGT(@"FDD · dúplex por frecuencia", @"FDD · frequency division duplex")
                footer:BLGT(@"Bandas con subida y bajada en bloques de frecuencia separados.",
                             @"Bands with uplink and downlink on separate frequency blocks.")
                 bands:BLGBandsForDuplex(_supportedBands, @"FDD")
                 items:items];

    [self addBandGroup:BLGT(@"TDD · dúplex por tiempo", @"TDD · time division duplex")
                footer:BLGT(@"Bandas que alternan subida y bajada en el tiempo dentro del mismo bloque de espectro.",
                             @"Bands that alternate uplink and downlink in time within the same spectrum block.")
                 bands:BLGBandsForDuplex(_supportedBands, @"TDD")
                 items:items];

    [self addBandGroup:BLGT(@"SDL · bajada suplementaria", @"SDL · supplemental downlink")
                footer:BLGT(@"Bandas solo de bajada que normalmente complementan otra portadora. Seleccionarlas por sí solas puede dejarte sin servicio.",
                             @"Downlink-only bands normally used together with another carrier. Selecting them alone can leave you without service.")
                 bands:BLGBandsForDuplex(_supportedBands, @"SDL")
                 items:items];

    NSMutableArray *classified = [NSMutableArray array];
    [classified addObjectsFromArray:BLGBandsForDuplex(_supportedBands, @"FDD")];
    [classified addObjectsFromArray:BLGBandsForDuplex(_supportedBands, @"TDD")];
    [classified addObjectsFromArray:BLGBandsForDuplex(_supportedBands, @"SDL")];
    NSMutableArray *other = [NSMutableArray array];
    NSSet *classifiedSet = [NSSet setWithArray:classified];
    for (NSNumber *band in _supportedBands) if (![classifiedSet containsObject:band]) [other addObject:band];
    [self addBandGroup:BLGT(@"Otras bandas LTE", @"Other LTE bands")
                footer:BLGT(@"La banda está reportada por el módem, pero BandLock no dispone de metadatos completos para etiquetarla.",
                             @"The modem reports this band, but BandLock does not have complete metadata to label it.")
                 bands:other
                 items:items];

    PSSpecifier *actions = [PSSpecifier emptyGroupSpecifier];
    actions.name = BLGT(@"Acciones", @"Actions");
    [actions setProperty:BLGT(@"Los cambios quedan pendientes hasta volver a la pantalla principal y pulsar «Aplicar selección LTE».",
                                    @"Changes remain pending until you return to the main screen and tap “Apply LTE selection”.") forKey:@"footerText"];
    [items addObject:actions];

    PSSpecifier *all = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Seleccionar todas", @"Select all")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    all.buttonAction = @selector(selectAllSupported);
    [items addObject:all];

    PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Desmarcar todas", @"Clear selection")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    none.buttonAction = @selector(clearSelection);
    [items addObject:none];

    _specifiers = items;
    return _specifiers;
}

- (void)addBandGroup:(NSString *)name footer:(NSString *)footer bands:(NSArray<NSNumber *> *)bands items:(NSMutableArray *)items {
    if (!bands.count) return;
    PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
    group.name = name;
    [group setProperty:footer forKey:@"footerText"];
    [items addObject:group];

    for (NSNumber *band in bands) {
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:BLGBandTitle(band)
            target:self set:@selector(setBandValue:specifier:) get:@selector(bandValue:)
            detail:nil cell:PSSwitchCell edit:nil];
        [toggle setProperty:band forKey:@"band"];
        [items addObject:toggle];
    }
}

- (NSString *)selectedValue {
    return BLGBandList([[_selectedBands allObjects] sortedArrayUsingSelector:@selector(compare:)]);
}

- (id)bandValue:(PSSpecifier *)specifier {
    NSNumber *band = [specifier propertyForKey:@"band"];
    return @([_selectedBands containsObject:band]);
}

- (void)setBandValue:(id)value specifier:(PSSpecifier *)specifier {
    NSNumber *band = [specifier propertyForKey:@"band"];
    if (!band) return;
    if ([value boolValue]) [_selectedBands addObject:band];
    else [_selectedBands removeObject:band];
    [self savePending];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSArray<NSNumber *> *)availableFrom:(NSArray<NSNumber *> *)wanted {
    NSSet *supported = [NSSet setWithArray:_supportedBands];
    NSMutableArray *result = [NSMutableArray array];
    for (NSNumber *band in wanted ?: @[]) if ([supported containsObject:band]) [result addObject:band];
    return result;
}

- (void)savePending {
    BLGWriteState(@{@"pendingLTE": [[_selectedBands allObjects] sortedArrayUsingSelector:@selector(compare:)] ?: @[]});
}

- (void)setSelection:(NSArray<NSNumber *> *)bands {
    _selectedBands = [NSMutableSet setWithArray:[self availableFrom:bands]];
    [self savePending];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)selectCurrentActive { [self setSelection:_activeBands]; }
- (void)selectAllSupported { [self setSelection:_supportedBands]; }
- (void)selectFDD { [self setSelection:BLGBandsForDuplex(_supportedBands, @"FDD")]; }
- (void)selectTDD { [self setSelection:BLGBandsForDuplex(_supportedBands, @"TDD")]; }

- (void)clearSelection {
    _selectedBands = [NSMutableSet set];
    [self savePending];
    _specifiers = nil;
    [self reloadSpecifiers];
}

@end

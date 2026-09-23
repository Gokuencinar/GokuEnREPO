#import "BLBandSelectionController.h"
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString * const BLStatePath = @"/var/mobile/Library/Preferences/com.local.bandlock.state.plist";

static NSArray<NSNumber *> *BLSortedBands(id bands) {
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

static NSString *BLBandList(NSArray<NSNumber *> *bands) {
    if (!bands.count) return @"Ninguna";
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:bands.count];
    for (NSNumber *band in bands) [parts addObject:[NSString stringWithFormat:@"B%@", band]];
    return [parts componentsJoinedByString:@", "];
}

static NSMutableDictionary *BLReadState(void) {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:BLStatePath];
    return state ? [state mutableCopy] : [NSMutableDictionary dictionary];
}

static void BLWriteState(NSDictionary *changes) {
    NSMutableDictionary *state = BLReadState();
    [changes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj) state[key] = obj;
        else [state removeObjectForKey:key];
    }];
    [state writeToFile:BLStatePath atomically:YES];
}

@interface BLBandSelectionController () {
    NSArray<NSNumber *> *_supportedBands;
    NSMutableSet<NSNumber *> *_selectedBands;
}
@end

@implementation BLBandSelectionController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Bandas LTE";

    NSMutableDictionary *state = BLReadState();
    _supportedBands = BLSortedBands(state[@"supportedSpain"]);
    NSArray *pending = BLSortedBands(state[@"pendingLTE"]);
    NSArray *active = BLSortedBands(state[@"activeSpain"]);
    _selectedBands = [NSMutableSet setWithArray:(pending.count ? pending : active)];

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
            title.text = @"Seleccionar bandas";
            title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
            title.textColor = UIColor.labelColor;
            [card addSubview:title];

            UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(60, 42, width - 125, 20)];
            subtitle.text = @"LTE utilizadas en España";
            subtitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            subtitle.textColor = UIColor.secondaryLabelColor;
            [card addSubview:subtitle];

            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 68, width - 60, 18)];
            caption.text = @"Los cambios quedan pendientes hasta pulsar Aplicar";
            caption.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
            caption.textColor = UIColor.tertiaryLabelColor;
            [card addSubview:caption];

            table.tableHeaderView = outer;
        }
    } @catch (__unused NSException *exception) {}
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSMutableDictionary *state = BLReadState();
    _supportedBands = BLSortedBands(state[@"supportedSpain"]);
    NSArray *pending = BLSortedBands(state[@"pendingLTE"]);
    NSArray *active = BLSortedBands(state[@"activeSpain"]);
    _selectedBands = [NSMutableSet setWithArray:(pending.count ? pending : active)];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSMutableArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];

    PSSpecifier *summaryGroup = [PSSpecifier emptyGroupSpecifier];
    summaryGroup.name = @"Selección";
    [summaryGroup setProperty:@"Estas son únicamente bandas LTE utilizadas por operadores en España y soportadas por tu iPhone. No se muestran bandas internacionales que no aportan utilidad aquí." forKey:@"footerText"];
    [items addObject:summaryGroup];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Seleccionadas"
        target:self set:nil get:@selector(selectedValue) detail:nil cell:PSTitleValueCell edit:nil]];

    if (!_supportedBands.count) {
        PSSpecifier *empty = [PSSpecifier emptyGroupSpecifier];
        empty.name = @"Sin datos";
        [empty setProperty:@"Vuelve a BandLock y pulsa «Actualizar estado» antes de entrar en esta pantalla." forKey:@"footerText"];
        [items addObject:empty];
        _specifiers = items;
        return _specifiers;
    }

    PSSpecifier *presetGroup = [PSSpecifier emptyGroupSpecifier];
    presetGroup.name = @"Perfiles";
    [presetGroup setProperty:@"Los perfiles solo preparan la selección; nada se escribe en el módem hasta volver a BandLock y pulsar «Aplicar selección LTE»." forKey:@"footerText"];
    [items addObject:presetGroup];

    NSArray *presets = @[
        @[@"Orange España", NSStringFromSelector(@selector(selectOrangeSpain))],
        @[@"Todas las de España", NSStringFromSelector(@selector(selectAllSpain))],
        @[@"Cobertura · 700/800/900", NSStringFromSelector(@selector(selectCoverage))],
        @[@"B3 + B7 · 1800/2600", NSStringFromSelector(@selector(selectB3B7))]
    ];
    for (NSArray *row in presets) {
        PSSpecifier *button = [PSSpecifier preferenceSpecifierNamed:row[0]
            target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        button.buttonAction = NSSelectorFromString(row[1]);
        [items addObject:button];
    }

    [self addBandGroup:@"Cobertura"
                footer:@"Bandas bajas, útiles para alcance y penetración en interiores. La disponibilidad depende de la red desplegada en tu zona."
                 bands:@[@28, @20, @8]
                labels:@{
                    @28: @"B28 · 700 MHz",
                    @20: @"B20 · 800 MHz",
                    @8:  @"B8 · 900 MHz"
                }
                 items:items];

    [self addBandGroup:@"Uso general"
                footer:@"Bandas medias muy habituales para LTE en España."
                 bands:@[@3, @1]
                labels:@{
                    @3: @"B3 · 1800 MHz",
                    @1: @"B1 · 2100 MHz"
                }
                 items:items];

    [self addBandGroup:@"Capacidad"
                footer:@"Bandas de mayor capacidad. B38 utiliza TDD y puede ser menos habitual según operador y emplazamiento."
                 bands:@[@7, @38]
                labels:@{
                    @7:  @"B7 · 2600 MHz FDD",
                    @38: @"B38 · 2600 MHz TDD"
                }
                 items:items];

    PSSpecifier *actions = [PSSpecifier emptyGroupSpecifier];
    actions.name = @"Acciones";
    [actions setProperty:@"Al volver a la pantalla principal verás esta selección como «Selección pendiente». Desde allí puedes aplicarla o restaurar el modo automático." forKey:@"footerText"];
    [items addObject:actions];

    PSSpecifier *all = [PSSpecifier preferenceSpecifierNamed:@"Seleccionar todas"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    all.buttonAction = @selector(selectAllSpain);
    [items addObject:all];

    PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:@"Desmarcar todas"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    none.buttonAction = @selector(clearSelection);
    [items addObject:none];

    _specifiers = items;
    return _specifiers;
}

- (void)addBandGroup:(NSString *)name
              footer:(NSString *)footer
               bands:(NSArray<NSNumber *> *)bands
              labels:(NSDictionary<NSNumber *, NSString *> *)labels
               items:(NSMutableArray *)items {
    NSMutableArray *available = [NSMutableArray array];
    for (NSNumber *band in bands) {
        if ([_supportedBands containsObject:band]) [available addObject:band];
    }
    if (!available.count) return;

    PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
    group.name = name;
    [group setProperty:footer forKey:@"footerText"];
    [items addObject:group];

    for (NSNumber *band in available) {
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:(labels[band] ?: [NSString stringWithFormat:@"B%@", band])
            target:self set:@selector(setBandValue:specifier:) get:@selector(bandValue:)
            detail:nil cell:PSSwitchCell edit:nil];
        [toggle setProperty:band forKey:@"band"];
        [items addObject:toggle];
    }
}

- (NSString *)selectedValue {
    NSArray *bands = [[_selectedBands allObjects] sortedArrayUsingSelector:@selector(compare:)];
    return BLBandList(bands);
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
    for (NSNumber *band in wanted) if ([supported containsObject:band]) [result addObject:band];
    return result;
}

- (void)savePending {
    NSArray *bands = [[_selectedBands allObjects] sortedArrayUsingSelector:@selector(compare:)];
    BLWriteState(@{@"pendingLTE": bands ?: @[]});
}

- (void)setSelection:(NSArray<NSNumber *> *)bands {
    _selectedBands = [NSMutableSet setWithArray:[self availableFrom:bands]];
    [self savePending];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)selectOrangeSpain {
    [self setSelection:@[@1, @3, @7, @8, @20, @28]];
}

- (void)selectAllSpain {
    [self setSelection:@[@1, @3, @7, @8, @20, @28, @38]];
}

- (void)selectCoverage {
    [self setSelection:@[@8, @20, @28]];
}

- (void)selectB3B7 {
    [self setSelection:@[@3, @7]];
}

- (void)clearSelection {
    _selectedBands = [NSMutableSet set];
    [self savePending];
    _specifiers = nil;
    [self reloadSpecifiers];
}

@end

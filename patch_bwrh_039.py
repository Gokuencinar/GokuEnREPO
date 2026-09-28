from pathlib import Path
import plistlib
import re

root = Path("BetterWiFi-RH")
tweak = root / "Tweak.xm"
s = tweak.read_text()

# Replace BWRHT with a manual language-aware implementation, regardless of
# the exact current helper body.
needle = "static NSString *BWRHT"
start = s.find(needle)
if start < 0:
    raise SystemExit("BWRHT helper not found")
brace = s.find("{", start)
if brace < 0:
    raise SystemExit("BWRHT opening brace not found")
depth = 0
end = None
for i in range(brace, len(s)):
    ch = s[i]
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            end = i + 1
            break
if end is None:
    raise SystemExit("BWRHT closing brace not found")

new_helper = r'''static NSInteger BWRHLanguageMode(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:BWRHPrefsDomain];
    id value = [defaults objectForKey:@"language"];
    NSInteger mode = value ? [value integerValue] : 0;
    return (mode >= 0 && mode <= 2) ? mode : 0;
}

static BOOL BWRHSystemUsesSpanish(void) {
    NSString *language = [NSLocale preferredLanguages].firstObject ?: @"en";
    return [[language lowercaseString] hasPrefix:@"es"];
}

static NSString *BWRHT(NSString *es, NSString *en) {
    NSInteger mode = BWRHLanguageMode();
    if (mode == 1) return es;
    if (mode == 2) return en;
    return BWRHSystemUsesSpanish() ? es : en;
}'''
s = s[:start] + new_helper + s[end:]

# The old automatic-language helper is no longer called directly by BWRHT.
# Keep it for compatibility with any future code but silence -Werror.
s = s.replace("static BOOL BWRHSpanish(void)", "static __attribute__((unused)) BOOL BWRHSpanish(void)", 1)
tweak.write_text(s)

# Add a language selector to the PreferenceBundle.
root_plist = root / "prefs/Resources/Root.plist"
prefs = plistlib.loads(root_plist.read_bytes())
items = prefs.get("items", prefs if isinstance(prefs, list) else [])
items = [x for x in items if not (isinstance(x, dict) and x.get("key") == "language")]

language_specifier = {
    "cell": "PSLinkListCell",
    "label": "Language",
    "defaults": "com.betterwifirh.preferences",
    "key": "language",
    "default": 0,
    "validValues": [0, 1, 2],
    "validTitles": ["Automatic", "Spanish", "English"],
    "PostNotification": "com.betterwifirh.preferences.changed",
}

insert_at = 2 if len(items) >= 2 else len(items)
items.insert(insert_at, language_specifier)
if isinstance(prefs, dict):
    prefs["items"] = items
else:
    prefs = {"items": items, "title": "BetterWiFi RH"}
root_plist.write_bytes(plistlib.dumps(prefs, fmt=plistlib.FMT_XML, sort_keys=False))

# Keep the Spanish resource complete and add the manual-language strings.
spanish = {
    "Advanced Wi-Fi controls for iOS 16 and RootHide. No background daemon is used.": "Controles Wi‑Fi avanzados para iOS 16 y RootHide. No utiliza ningún daemon en segundo plano.",
    "Advanced filters": "Filtros avanzados",
    "All": "Todas",
    "Automatic": "Automático",
    "BSSID in details": "BSSID en detalles",
    "BSSID in network list": "BSSID en la lista de redes",
    "Band (2.4 / 5 / 6 GHz)": "Banda (2,4 / 5 / 6 GHz)",
    "Band filter": "Filtro de banda",
    "BetterWiFi RH": "BetterWiFi RH",
    "BetterWiFi classic": "BetterWiFi clásico",
    "BetterWiFi details section": "Sección de detalles BetterWiFi",
    "Ch.": "Canal",
    "Channel": "Canal",
    "Channel width in details": "Ancho de canal en detalles",
    "Choose the technical information shown next to Wi-Fi networks.": "Elige la información técnica que se muestra junto a las redes Wi‑Fi.",
    "Classic BetterWiFi-style list behavior. Unfiltered scanning can reveal weaker access points but does not increase antenna power.": "Comportamiento clásico de BetterWiFi. El escaneo sin filtrar puede mostrar puntos de acceso más débiles, pero no aumenta la potencia de la antena.",
    "Connected network": "Red conectada",
    "DNS servers": "Servidores DNS",
    "Diagnostic tools": "Herramientas de diagnóstico",
    "Diagnostics & battery": "Diagnóstico y batería",
    "Efficient monitoring mode": "Modo de monitorización eficiente",
    "Enabled": "Activado",
    "English": "Inglés",
    "Extra info in current network row": "Información extra en la red actual",
    "Filters are applied only to the Wi-Fi list. The channel analyzer keeps the complete scan snapshot.": "Los filtros se aplican solo a la lista Wi‑Fi. El analizador de canales conserva una captura completa del escaneo.",
    "IPv4 address": "Dirección IPv4",
    "Known": "Conocidas",
    "Language": "Idioma",
    "Minimum dBm": "dBm mínimos",
    "Minimum signal filter": "Filtro de señal mínima",
    "Name": "Nombre",
    "Network information": "Información de las redes",
    "Network type": "Tipo de red",
    "New": "Nuevas",
    "Private Wi-Fi address": "Dirección Wi‑Fi privada",
    "Pull to refresh": "Deslizar para actualizar",
    "Remove signal filtering": "Eliminar filtrado por señal",
    "Router address": "Dirección del router",
    "Security type": "Tipo de seguridad",
    "Show only open networks": "Mostrar solo redes abiertas",
    "Shows additional data in the current network row and inside the ⓘ information page.": "Muestra datos adicionales en la fila de la red actual y dentro de su página de información ⓘ.",
    "Signal": "Señal",
    "Signal monitoring scans only while its screen is open. Efficient mode uses a slower refresh interval to reduce radio activity.": "El monitor de señal solo escanea mientras su pantalla está abierta. El modo eficiente usa un intervalo más lento para reducir la actividad de la radio.",
    "Signal strength (dBm)": "Intensidad de señal (dBm)",
    "Sort networks": "Ordenar redes",
    "Spanish": "Español",
}
es_dir = root / "prefs/Resources/es.lproj"
es_dir.mkdir(parents=True, exist_ok=True)
lines = []
for key, value in sorted(spanish.items()):
    k = key.replace("\\", "\\\\").replace('"', '\\"')
    v = value.replace("\\", "\\\\").replace('"', '\\"')
    lines.append(f'"{k}" = "{v}";')
(es_dir / "Root.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")

# Make the PreferenceBundle honor the manual language immediately.
controller = root / "prefs/BWRHRootListController.m"
controller.write_text(r'''#import "BWRHRootListController.h"
#import <Preferences/PSSpecifier.h>

static NSString * const BWRHPrefsDomain = @"com.betterwifirh.preferences";

static NSInteger BWRHPrefsLanguageMode(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:BWRHPrefsDomain];
    id value = [defaults objectForKey:@"language"];
    NSInteger mode = value ? [value integerValue] : 0;
    return (mode >= 0 && mode <= 2) ? mode : 0;
}

static NSDictionary *BWRHSpanishPreferenceStrings(void) {
    static NSDictionary *strings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleForClass:[BWRHRootListController class]];
        NSString *path = [bundle pathForResource:@"Root" ofType:@"strings" inDirectory:@"es.lproj"];
        NSDictionary *loaded = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
        strings = loaded ?: @{};
    });
    return strings;
}

static NSString *BWRHPreferenceStringForMode(NSString *value, NSInteger mode) {
    if (!value.length || mode == 0) return value;

    NSDictionary *spanish = BWRHSpanishPreferenceStrings();
    if (mode == 1) {
        NSString *translated = spanish[value];
        if (translated.length) return translated;
        // The system may already have localized the string to Spanish.
        if ([[spanish allValues] containsObject:value]) return value;
        return value;
    }

    // English mode: Root.plist uses English keys, so reverse a Spanish value
    // if the system localized the specifier before we got it.
    for (NSString *english in spanish) {
        NSString *translated = spanish[english];
        if ([translated isEqualToString:value]) return english;
    }
    return value;
}

static NSArray *BWRHPreferenceTitlesForMode(NSArray *titles, NSInteger mode) {
    if (![titles isKindOfClass:[NSArray class]] || mode == 0) return titles;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:titles.count];
    for (id title in titles) {
        if ([title isKindOfClass:[NSString class]]) {
            [result addObject:BWRHPreferenceStringForMode(title, mode)];
        } else {
            [result addObject:title];
        }
    }
    return result;
}

@implementation BWRHRootListController

- (void)bwrh_applyLanguageToSpecifiers {
    NSInteger mode = BWRHPrefsLanguageMode();
    if (mode == 0) return;

    for (PSSpecifier *specifier in _specifiers) {
        NSString *name = specifier.name;
        if (name.length) specifier.name = BWRHPreferenceStringForMode(name, mode);

        NSString *footer = [specifier propertyForKey:@"footerText"];
        if ([footer isKindOfClass:[NSString class]] && footer.length) {
            [specifier setProperty:BWRHPreferenceStringForMode(footer, mode) forKey:@"footerText"];
        }

        NSArray *titles = [specifier propertyForKey:@"validTitles"];
        if ([titles isKindOfClass:[NSArray class]]) {
            [specifier setProperty:BWRHPreferenceTitlesForMode(titles, mode) forKey:@"validTitles"];
        }
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        if (!_specifiers) _specifiers = [NSMutableArray array];
        [self bwrh_applyLanguageToSpecifiers];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"BetterWiFi RH";
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"language"]) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:BWRHPrefsDomain];
        [defaults setObject:value forKey:@"language"];
        [defaults synchronize];

        _specifiers = nil;
        [self reloadSpecifiers];
        self.title = @"BetterWiFi RH";
    }
}

@end
''', encoding="utf-8")

# Version bump.
control = root / "control"
ct = control.read_text().replace("Version: 0.3.8", "Version: 0.3.9")
if "Version: 0.3.9" not in ct:
    raise SystemExit("control version patch failed")
control.write_text(ct)

info_path = root / "prefs/Resources/Info.plist"
info = plistlib.loads(info_path.read_bytes())
info["CFBundleShortVersionString"] = "0.3.9"
info["CFBundleVersion"] = "12"
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=False))

print("BetterWiFi RH 0.3.9 manual language selector patch applied")

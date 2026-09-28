from pathlib import Path
p=Path("BetterWiFi-RH/Tweak.xm")
s=p.read_text()
repls={
"static long long BWRHMWReadRSSI(void) {":"static __attribute__((unused)) long long BWRHMWReadRSSI(void) {",
"static BWRHMobileWiFiNetwork *BWRHMWCurrentNetworkRecord(void) {":"static __attribute__((unused)) BWRHMobileWiFiNetwork *BWRHMWCurrentNetworkRecord(void) {",
"static BOOL BWRHMWStartScan(void) {":"static __attribute__((unused)) BOOL BWRHMWStartScan(void) {",
}
for a,b in repls.items():
    if a not in s: raise SystemExit("missing: "+a)
    s=s.replace(a,b,1)
p.write_text(s)

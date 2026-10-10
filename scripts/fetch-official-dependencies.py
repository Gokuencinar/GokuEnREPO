"""Download public upstream packages for review. Does not publish or install."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import lzma
import re
import subprocess
import urllib.parse
import urllib.request

OUT = Path('.build/dependency-downloads')
SPECS = {
    'roothide': ('https://roothide.github.io/procursus/', 'iphoneos-arm64e/1900', 'iphoneos-arm64e'),
    'rootless': ('https://apt.procurs.us/', 'iphoneos-arm64-rootless/1800', 'iphoneos-arm64'),
    'rootful': ('https://apt.procurs.us/', 'iphoneos-arm64/1800', 'iphoneos-arm'),
}
# Bootstrap-owned packages (firmware, roothide, libiosexec1, ca-certificates)
# must come from the installed jailbreak, not a cross-scheme mirror.
NAMES = ['arpoison', 'ldid', 'network-cmds', 'libnet9', 'libssl3', 'libplist3', 'libpcapa']

def read(url, limit):
    request = urllib.request.Request(url, headers={
        'User-Agent': 'GokuEnREPO/1.0 (+https://github.com/Gokuencinar/GokuEnREPO)',
    })
    with urllib.request.urlopen(request, timeout=45) as response:
        raw = response.read(limit+1)
    if len(raw) > limit:
        raise ValueError('download exceeds bound')
    return raw

def fields(block):
    result = {}
    for line in block.splitlines():
        if line and not line.startswith((' ', '\t')) and ': ' in line:
            key, value = line.split(': ', 1)
            result[key] = value
    return result

def fetch(item):
    scheme, (base, suite, architecture) = item
    folder = OUT/scheme
    folder.mkdir(parents=True, exist_ok=True)
    report = {'scheme':scheme, 'architecture':architecture, 'base':base, 'suite':suite, 'packages':[], 'errors':[]}
    try:
        release_url = base+'dists/'+suite+'/Release'
        release = read(release_url, 1024*1024)
        assert fields(release.decode('utf-8')).get('Architectures') == architecture
        report['release_url'] = release_url
        report['release_sha256'] = hashlib.sha256(release).hexdigest()
        (folder/'Release').write_bytes(release)
        relative = f'main/binary-{architecture}/Packages.xz'
        sha_section = release.decode().split('SHA256:\n',1)[1].split('\nSHA',1)[0]
        matching = [line.split() for line in sha_section.splitlines() if line.strip().endswith(' '+relative)]
        assert len(matching) == 1
        digest, size, _ = matching[0]
        packed = read(base+'dists/'+suite+'/'+relative, 16*1024*1024)
        assert len(packed) == int(size) and hashlib.sha256(packed).hexdigest() == digest
        report['index_sha256'] = digest
        index = lzma.decompress(packed).decode('utf-8')
        (folder/'Packages').write_text(index, encoding='utf-8')
        candidates = [fields(block) for block in index.split('\n\n')]
        for name in NAMES:
            matches = [f for f in candidates if f.get('Package') == name and f.get('Architecture') in [architecture, 'all']]
            if not matches:
                report['errors'].append('Not in upstream index: '+name)
                continue
            chosen = matches[0]
            for candidate in matches[1:]:
                if subprocess.run(['dpkg','--compare-versions',candidate['Version'],'gt',chosen['Version']]).returncode == 0:
                    chosen = candidate
            relative = chosen['Filename']
            assert not relative.startswith('/') and '..' not in Path(relative).parts
            url = urllib.parse.urljoin(base, relative)
            assert url.startswith(base)
            raw = read(url, 64*1024*1024)
            assert len(raw) == int(chosen['Size']) and hashlib.sha256(raw).hexdigest() == chosen['SHA256']
            filename = Path(relative).name
            (folder/filename).write_bytes(raw)
            info = subprocess.check_output(['dpkg-deb','-f',str(folder/filename)],text=True)
            parsed = fields(info)
            assert all(parsed.get(k) == chosen[k] for k in ['Package','Version','Architecture'])
            report['packages'].append({'fields':chosen,'url':url,'file':filename})
    except Exception as error:
        report['errors'].append(type(error).__name__+': '+str(error))
    (folder/'download-manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(scheme,len(report['packages']),report['errors'],flush=True)
    return report

if __name__ == '__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        reports = list(pool.map(fetch,SPECS.items()))
    (OUT/'summary.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf-8')
    if any(r['errors'] for r in reports):
        raise SystemExit('Some upstream downloads need attention; inspect the artifact')

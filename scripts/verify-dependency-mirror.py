"""Inspect mirrored DEBs and their provenance; never install or execute them."""
from pathlib import Path, PurePosixPath
import gzip
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent.parent
MIRROR = ROOT/'tweaks/NukeWireless-Dependencies'
ARCHES = {'roothide':'iphoneos-arm64e', 'rootless':'iphoneos-arm64', 'rootful':'iphoneos-arm'}
NAMES = {'arpoison', 'ldid', 'network-cmds', 'libnet9', 'libssl3', 'libplist3', 'libpcapa'}
BOOTSTRAP = {'firmware', 'roothide', 'libiosexec1', 'ca-certificates'}

def fields(text):
    result = {}
    key = None
    for line in text.splitlines():
        if line.startswith((' ', '\t')) and key:
            result[key] += '\n'+line
        elif ': ' in line:
            key, value = line.split(': ', 1)
            result[key] = value
    return result

def archive(path, kind):
    if shutil.which('dpkg-deb'):
        flag = '--ctrl-tarfile' if kind == 'control' else '--fsys-tarfile'
        raw = subprocess.check_output(['dpkg-deb', flag, str(path)])
    else:
        # Windows review fallback. Linux CI uses dpkg-deb above.
        raw = path.read_bytes()
        assert raw[:8] == b'!<arch>\n'
        position = 8
        while position < len(raw):
            header = raw[position:position+60]
            assert header[58:60] == b'`\n'
            name = header[:16].decode('ascii').strip().rstrip('/')
            size = int(header[48:58])
            content = raw[position+60:position+60+size]
            position += 60+size+(size % 2)
            if name.startswith(kind+'.tar'):
                raw = content
                if name.endswith('.zst'):
                    import zstandard
                    raw = zstandard.ZstdDecompressor().decompress(raw, max_output_size=128*1024*1024)
                break
        else:
            raise ValueError('Missing '+kind+' archive')
    return tarfile.open(fileobj=io.BytesIO(raw), mode='r:*')

def check_hash(path, expected, size):
    raw = path.read_bytes()
    assert len(raw) == int(size), path
    assert hashlib.sha256(raw).hexdigest() == expected, path

entries = json.loads((MIRROR/'binary-manifest.json').read_text(encoding='utf-8'))
assert len(entries) == 21
assert {p.name for p in (MIRROR/'debs').glob('*.deb')} == {e['file'] for e in entries}
packages = {}
for item in entries:
    metadata = item['fields']
    scheme = item['scheme']
    assert metadata['Architecture'] == item['architecture'] == ARCHES[scheme]
    assert metadata['Package'] in NAMES
    assert item['file'] == Path(item['file']).name
    assert item['url'].startswith(('https://apt.procurs.us/pool/', 'https://roothide.github.io/procursus/pool/'))
    for key in ('release_sha256', 'index_sha256'):
        assert re.fullmatch('[0-9a-f]{64}', item[key])
    path = MIRROR/'debs'/item['file']
    check_hash(path, metadata['SHA256'], metadata['Size'])
    with archive(path, 'control') as control:
        member = next(m for m in control if PurePosixPath(m.name).name == 'control')
        actual = fields(control.extractfile(member).read().decode('utf-8'))
        for key in ('Package','Version','Architecture','Maintainer','Depends','Pre-Depends','Provides','Conflicts','Replaces'):
            assert actual.get(key) == metadata.get(key), (path,key)
        # Reviewed originals currently have no executable maintainer scripts.
        assert not any(PurePosixPath(m.name).name in {'preinst','postinst','prerm','postrm','config'} for m in control)
    with archive(path, 'data') as data:
        files = [m.name.removeprefix('./') for m in data if m.isfile()]
        assert files
        assert all(not PurePosixPath(p).is_absolute() and '..' not in PurePosixPath(p).parts for p in files)
        assert all(p.startswith('var/jb/') for p in files) if scheme == 'rootless' else all(not p.startswith('var/jb/') for p in files)
        if metadata['Package'] in {'arpoison','ldid'}:
            prefix = 'var/jb/' if scheme == 'rootless' else ''
            assert prefix+'usr/bin/'+metadata['Package'] in files
    key = scheme,metadata['Package']
    assert key not in packages
    packages[key] = metadata

external = set()
for (scheme, name), metadata in packages.items():
    for relation in ('Depends','Pre-Depends'):
        for clause in metadata.get(relation, '').split(','):
            if not clause.strip(): continue
            supported = False
            for alternative in clause.split('|'):
                match = re.fullmatch(r'\s*([a-z0-9+.-]+)(?:\s*\((>=|<=|=|>>|<<)\s*([^ )]+)\))?\s*', alternative)
                assert match, clause
                dependency, operator, version = match.groups()
                target = packages.get((scheme,dependency))
                if target:
                    if operator and shutil.which('dpkg'):
                        assert subprocess.run(['dpkg','--compare-versions',target['Version'],operator,version]).returncode == 0
                    supported = True
                    break
                if dependency in BOOTSTRAP:
                    external.add((scheme,alternative.strip()))
                    supported = True
                    break
            assert supported, (scheme,name,clause)

sources = json.loads((MIRROR/'source-manifest.json').read_text(encoding='utf-8'))
assert len(sources) == 12
for source in sources:
    path = MIRROR/source['file']
    assert path.resolve().is_relative_to((MIRROR/'sources').resolve())
    check_hash(path, source['sha256'], source['size'])
    assert source['license_members'], path

if '--index' in sys.argv:
    raw = (ROOT/'Packages').read_bytes()
    assert gzip.decompress((ROOT/'Packages.gz').read_bytes()) == raw
    index = [fields(block) for block in raw.decode('utf-8').split('\n\n') if block.strip()]
    for item in entries:
        original = item['fields']
        matches = [p for p in index if all(p.get(k) == original[k] for k in ('Package','Version','Architecture'))]
        assert len(matches) == 1
        actual = matches[0]
        assert actual['Filename'] == 'tweaks/NukeWireless-Dependencies/debs/'+item['file']
        for key in ('SHA256','Size','Maintainer','Depends'):
            assert actual.get(key) == original.get(key), (item['file'],key)

print('Verified 21 original DEBs, 3 schemes, payload paths, internal dependencies and 12 source/recipe archives.')
print('External bootstrap requirements (not supplied by this mirror):')
for scheme, requirement in sorted(external):
    print('  '+scheme+': '+requirement)

"""Regression tests using synthetic Mach-O fixtures; no tweak binaries needed."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
AWK=os.environ.get('GAWK') or shutil.which('gawk') or shutil.which('awk')

def command(path,be=False):
    text=path.encode()+b'\0';size=(12+len(text)+7)&~7
    return struct.pack(('>' if be else '<')+'III',0x8000001c,size,12)+text+b'\0'*(size-12-len(text))

def thin(paths,be=False,bits=64):
    commands=b''.join(command(p,be) for p in paths)
    header=struct.pack(('>' if be else '<')+'IIIIIII',0xfeedfacf if bits==64 else 0xfeedface,0x100000c,0,6,len(paths),len(commands),0)
    if bits==64:header+=b'\0'*4
    return header+commands+b'\nPAYLOAD\x00\xff\n'*20

def universal(parts,bits=32,be=True):
    end='>' if be else '<';step=32 if bits==64 else 20
    offset=8+len(parts)*step;entries=b''
    for i,part in enumerate(parts):
        entries+=struct.pack(end+('IIQQII' if bits==64 else 'IIIII'),0x100000c,i,offset,len(part),0,*([0] if bits==64 else []))
        offset+=len(part)
    return struct.pack(end+'II',0xcafebabf if bits==64 else 0xcafebabe,len(parts))+entries+b''.join(parts)

def paths(blob):
    if blob[:4] in (b'\xca\xfe\xba\xbe',b'\xca\xfe\xba\xbf',b'\xbe\xba\xfe\xca',b'\xbf\xba\xfe\xca'):
        be=blob[:4] in (b'\xca\xfe\xba\xbe',b'\xca\xfe\xba\xbf');end='>' if be else '<'
        fat64=blob[:4] in (b'\xca\xfe\xba\xbf',b'\xbf\xba\xfe\xca');step=32 if fat64 else 20
        result=[]
        for i in range(struct.unpack_from(end+'I',blob,4)[0]):
            start,size=struct.unpack_from(end+('QQ' if fat64 else 'II'),blob,8+i*step+8)
            result.extend(paths(blob[start:start+size]))
        return result
    be=blob[:4] in (b'\xfe\xed\xfa\xce',b'\xfe\xed\xfa\xcf');end='>' if be else '<'
    magic=struct.unpack_from(end+'I',blob)[0];header=32 if magic==0xfeedfacf else 28
    count,size=struct.unpack_from(end+'II',blob,16);p=header;out=[]
    for _ in range(count):
        cmd,length=struct.unpack_from(end+'II',blob,p)
        if cmd==0x8000001c:
            string=struct.unpack_from(end+'I',blob,p+8)[0]
            out.append(blob[p+string:p+length].split(b'\0')[0].decode())
        p+=length
    return [out]

class RPaths(unittest.TestCase):
    def invoke(self,blob,check=False):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'fixture with spaces.macho';path.write_bytes(blob)
            env=dict(os.environ,LC_ALL='C',RH_RPATH_INPUT=path.as_posix())
            args=[AWK]+(['-v','check=1'] if check else [])+['-f',(ROOT/'src'/'rpath_dedup.awk').as_posix()]
            result=subprocess.run(args,capture_output=True,env=env,check=False)
            self.assertEqual(path.read_bytes(),blob,'helper must not modify its input')
            return result
    def test_architectures_order_payload_and_idempotence(self):
        fixtures=[thin(['/b','/a','/b','/c','/a']),thin(['/b','/b','/a'],True,32),universal([thin(['/a','/a','/b']),thin(['/c','/a','/c'])]),universal([thin(['/x','/x'],True),thin(['/y','/y'])],64,False)]
        for before in fixtures:
            with self.subTest(paths=paths(before)):
                self.assertEqual(self.invoke(before,True).returncode,2)
                result=self.invoke(before);self.assertEqual(result.returncode,0,result.stderr)
                self.assertEqual(paths(result.stdout),[list(dict.fromkeys(p)) for p in paths(before)])
                self.assertEqual(len(result.stdout),len(before))
                self.assertEqual(result.stdout.count(b'\nPAYLOAD\x00\xff\n'),before.count(b'\nPAYLOAD\x00\xff\n'))
                self.assertEqual(self.invoke(result.stdout,True).returncode,0)
                self.assertEqual(self.invoke(result.stdout).stdout,result.stdout)
    def test_clean_file_unchanged(self):
        before=thin(['/a','/b']);self.assertEqual(self.invoke(before).stdout,before)
    def test_invalid_inputs_do_not_emit_partial_output(self):
        for before in [b'invalid',thin(['/a','/a'])[:45],universal([thin(['/a','/a']),b'invalid'])]:
            with self.subTest(size=len(before)):
                result=self.invoke(before);self.assertEqual(result.returncode,1);self.assertEqual(result.stdout,b'')

if __name__=='__main__':unittest.main()

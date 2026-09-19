#!/usr/bin/env python3
"""Differential replay for the authorized T-0032/S05 finite-decimal domain."""
import hashlib, importlib.util, json, os, signal, stat, subprocess, sys, tempfile, uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]; OP=ROOT/'tools/t0032-finite-decimal-oracle/run.py'
S=importlib.util.spec_from_file_location('oracle',OP); oracle=importlib.util.module_from_spec(S); S.loader.exec_module(oracle)
TIMEOUT=90; CAP=32*1024*1024
def req(v,m):
    if not v: raise ValueError(m)
def sha(b): return hashlib.sha256(b).hexdigest()
def regular(p,r,cap=CAP):
    p=Path(p); m=p.lstat(); req(stat.S_ISREG(m.st_mode) and not stat.S_ISLNK(m.st_mode),'not regular')
    q=p.resolve(); rr=Path(r).resolve(); req(q!=rr and rr in q.parents,'path escape'); req(m.st_size<=cap,'cap')
    b=p.read_bytes(); req(len(b)==m.st_size,'changed'); return {'name':str(p.relative_to(r)),'size':len(b),'sha256':sha(b)}
def tree(r):
    out=[]; total=0
    for p in sorted(Path(r).rglob('*')):
      m=p.lstat(); req(not stat.S_ISLNK(m.st_mode),'symlink')
      if stat.S_ISDIR(m.st_mode): out.append({'name':str(p.relative_to(r)),'type':'directory'})
      elif stat.S_ISREG(m.st_mode): total+=m.st_size; req(total<=CAP,'tree cap'); out.append({'type':'regular',**regular(p,r,CAP-total+m.st_size)})
      else: raise ValueError('special')
    return out
def exe():
    p=Path(os.environ['EMBURK_BINARY']); m=p.lstat(); req(not stat.S_ISLNK(m.st_mode),'binary symlink'); p=p.resolve(); req(os.access(p,os.X_OK),'binary'); return p
def run(cmd,r,label,env):
    a,b=Path(r)/(label+'.out'),Path(r)/(label+'.err')
    with a.open('xb') as o,b.open('xb') as e:
      x=subprocess.Popen(cmd,cwd=r,env=env,stdout=o,stderr=e,start_new_session=True)
      try: code=x.wait(TIMEOUT); timeout=False
      except subprocess.TimeoutExpired: os.killpg(x.pid,signal.SIGKILL); code=x.wait(); timeout=True
    z=Path(r)/(label+'.exit'); z.write_text(str(code)+'\n')
    return {'exit':code,'timed_out':timeout,'out':regular(a,r),'err':regular(b,r),'exit_file':regular(z,r)}
def output(r): return tree(r)
def oracle_run():
    x=subprocess.run([sys.executable,'-I','-B',str(OP)],cwd=ROOT,env=os.environ,stdout=subprocess.PIPE,timeout=360)
    p=[l[24:] for l in x.stdout.decode().splitlines() if l.startswith('T0032_S05_EVIDENCE_DIR=')]
    req(x.returncode==0 and len(p)==1,'oracle'); q=Path(p[0])/'manifest.json'; oracle.validate_summary(q); return {'path':str(q.parent),'manifest_sha256':sha(q.read_bytes())}
def profile(case,base,where):
    p=oracle.config(case).replace(b'output/result',where+b'/result'); (base/'config.yml').write_bytes(p)
def compare(case,r,jar,java,version,binary,u):
    c=r/'cases'/case; c.mkdir(parents=True); [ (c/n).mkdir() for n in ('ref','native','home','tmp') ]; (c/'input.csv').write_bytes(oracle.fixture(case)); (c/'java.txt').write_bytes(version)
    profile(case,c,b'ref'); (c/'config.yml').rename(c/'ref.yml'); profile(case,c,b'native'); (c/'config.yml').rename(c/'native.yml')
    a=run([str(java),'-Duser.home='+str(c/'home'),'-Djava.io.tmpdir='+str(c/'tmp'),'-jar',str(jar),'-Xembulk_home='+str(c/'home'),'run','ref.yml'],c,'refp',{'PATH':os.defpath,'JAVA_HOME':str(java.parent.parent),'HOME':str(c/'home'),'TMPDIR':str(c/'tmp')})
    b=run([str(binary),'run','native.yml'],c,'natp',{'PATH':os.defpath}); ro,no=output(c/'ref'),output(c/'native'); req(not a['timed_out'] and not b['timed_out'] and a['exit']==b['exit'] and ro==no,'differential')
    v={'case':case,'run_uuid':u,'input':regular(c/'input.csv',c),'ref':a,'native':b,'refout':ro,'nativeout':no}; v['tree']=tree(c); (c/'manifest.json').write_text(json.dumps(v,sort_keys=True)+'\n'); return c/'manifest.json'
def main():
    stage=oracle_run(); data=oracle.reference(os.environ); java,ver,_=oracle.java17(os.environ); b=exe(); r=Path(tempfile.mkdtemp(prefix='emburk-t0032-s05-diff-',dir='/private/tmp')); r.chmod(0o700); jar=r/'embulk.jar'; jar.write_bytes(data); native=r/'emburk'; native.write_bytes(b.read_bytes()); native.chmod(0o500); u=str(uuid.uuid4()); cases=('family-corpus','prior-null-sentinel','seeded-holdout'); ms=[]
    for c in cases: ms.append({'case':c,'sha256':sha(compare(c,r,jar,java,ver,native,u).read_bytes())})
    v={'run_uuid':u,'stage_a':stage,'jar':regular(jar,r),'binary':regular(native,r),'cases':ms,'result':'pass'}; v['tree']=tree(r); (r/'manifest.json').write_text(json.dumps(v,sort_keys=True)+'\n'); print('T0032_S05_EVIDENCE_DIR='+str(r))
if __name__=='__main__':
  try: main()
  except (OSError,ValueError,subprocess.SubprocessError) as e: print('T0032_S05_ERROR='+str(e),file=sys.stderr); raise SystemExit(2)

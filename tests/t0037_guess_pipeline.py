"""Selected real guess/transfer comparisons and native checkpoint recovery."""
import bz2
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

REPO=Path(__file__).resolve().parents[1]
BINARY=REPO/"target/debug/emburk"
BASE=Path(tempfile.mkdtemp(prefix="emburk-t0037-pipeline-"))
RESULT={"complete":False,"cases":[],"recovery":[]}

def require(ok,message):
    if not ok: raise ValueError(message)
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def record(root):
    result={}
    for path in sorted(root.rglob("*")):
        require(not path.is_symlink(),"evidence symlink")
        if path.is_file():result[str(path.relative_to(root))]={"size":path.stat().st_size,"sha256":digest(path)}
    return result
def kill_owned(child):
    if child.poll() is None:
        try:os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError:pass
    return child.wait()
def process(command,root,label,env=None,expected=0,timeout=180):
    with (root/(label+".stdout")).open("xb") as stdout,(root/(label+".stderr")).open("xb") as stderr:
        child=subprocess.Popen(command,cwd=root,env=env,stdout=stdout,stderr=stderr,start_new_session=True)
        timed_out=False;code=None
        try:code=child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out=True;code=kill_owned(child);raise
        finally:
            if code is None:code=kill_owned(child)
            (root/(label+".process.json")).write_text(json.dumps({"command":list(map(str,command)),"pid":child.pid,"exit":code,"timeout":timed_out})+"\n")
    require(code==expected,f"unexpected exit {label}: {code}")
    return (root/(label+".stdout")).read_bytes()

RUBY=r'''
require 'psych'; require 'json'
def tree(n)
 case n
 when Psych::Nodes::Document then tree(n.children.fetch(0))
 when Psych::Nodes::Scalar then n.value
 when Psych::Nodes::Sequence then n.children.map{|c|tree(c)}
 when Psych::Nodes::Mapping
  h={};n.children.each_slice(2){|k,v| key=tree(k);raise 'duplicate key' if h.key?(key);h[key]=tree(v)};h
 else raise 'unsupported YAML node'
 end
end
puts JSON.generate(tree(Psych.parse(File.read(ARGV.fetch(0)))))
'''
def semantic(path,root,label):
    return json.loads(process(["ruby","-e",RUBY,str(path)],root,label))
def java_command(root,jar):
    (root/"home").mkdir();(root/"tmp").mkdir()
    java=str(Path(os.environ["JAVA_HOME"])/"bin/java")
    return [java,f"-Duser.home={root/'home'}",f"-Djava.io.tmpdir={root/'tmp'}","-jar",str(jar),"-X",f"embulk_home={root/'home'}","run","config.yml"]
def outputs(root):
    return {str(p.relative_to(root/"output")):p.read_bytes() for p in sorted((root/"output").rglob("*")) if p.is_file()}
def isolated(name,input_bytes,config):
    root=BASE/name;root.mkdir();(root/"output").mkdir();(root/"input").write_bytes(input_bytes);(root/"config.yml").write_bytes(config);return root
def interrupt(root):
    command=[str(BINARY),"run","config.yml","--state","state"]
    with (root/"interrupted.stdout").open("xb") as stdout,(root/"interrupted.stderr").open("xb") as stderr:
        child=subprocess.Popen(command,cwd=root,stdout=stdout,stderr=stderr,start_new_session=True)
        code=None;timed_out=False
        try:
            deadline=time.monotonic()+30
            while not (root/"state/00000000000000000001.json").exists():
                require(child.poll() is None,"job ended before checkpoint interruption")
                require(time.monotonic()<deadline,"checkpoint timeout")
                time.sleep(.002)
            child.send_signal(signal.SIGINT);code=child.wait(timeout=30)
        except subprocess.TimeoutExpired:
            timed_out=True;raise
        finally:
            if code is None:code=kill_owned(child)
            (root/"interrupted.process.json").write_text(json.dumps({"command":command,"pid":child.pid,"exit":code,"timeout":timed_out})+"\n")
    require(code==130,"SIGINT exit must be 130")
    require(not outputs(root),"interrupted job published output")

def main():
    RESULT["revision"]=subprocess.check_output(["git","rev-parse","HEAD"],cwd=REPO,text=True).strip()
    RESULT["binary_sha256"]=digest(BINARY)
    if os.environ.get("EMBURK_TEST_PIPELINE_TIMEOUT"):
        process([sys.executable,"-c","import time;time.sleep(30)"],BASE,"forced-timeout",timeout=.1)
    RESULT["ruby"]=process(["ruby","-rpsych","-e","puts RUBY_VERSION;puts Psych::VERSION"],BASE,"ruby-version").decode()
    raw=process([sys.executable,"-B",str(REPO/"tools/guess-oracle/run.py")],BASE,"guess-reference",os.environ.copy())
    roots=[line.split("=",1)[1] for line in raw.decode().splitlines() if line.startswith("GUESS_ROOT=")]
    require(len(roots)==1,"missing reference root");reference=Path(roots[0]);jar=reference/"embulk.jar"
    RESULT["reference_root"]=str(reference);RESULT["reference_sha256"]=digest(jar)
    env={"PATH":os.defpath,"JAVA_HOME":os.environ["JAVA_HOME"]}
    for case in ["csv","json","gzip","bzip2","empty","ambiguous","headerless","tsv","json-columns","headerless-utf8"]:
        observed=reference/case
        native=BASE/("guess-"+case);native.mkdir();shutil.copyfile(observed/"input",native/"input");shutil.copyfile(observed/"seed.yml",native/"seed.yml")
        gap=case in {"headerless","tsv"};rejected=gap or case=="empty"
        process([str(BINARY),"guess","seed.yml","-o","config.yml"],native,"guess",expected=1 if rejected else 0)
        entry={"case":case,"class":"unsupported-gap" if gap else "matched-rejection" if rejected else "matched-config"}
        if rejected:
            require(not (native/"config.yml").exists(),"rejected guess created configuration")
            reason={"empty":"cannot guess empty input","headerless":"headerless numeric input requires explicit charset","tsv":"unsupported possible delimiter"}[case]
            require(reason in (native/"guess.stderr").read_text(),"unexpected rejection class: "+case)
            entry["native_reason"]=reason
            entry["reference_exit"]=1 if case=="empty" else 0
        if not rejected:
            expected=semantic(observed/"guessed.yml",native,"reference-tree");actual=semantic(native/"config.yml",native,"native-tree")
            if os.environ.get("EMBURK_TEST_PIPELINE_MISMATCH"):actual["in"]["parser"]["type"]="forced-mismatch"
            require(actual==expected,"guessed scalar tree mismatch: "+case)
            if case!="json":
                r=isolated("run-reference-"+case,(observed/"input").read_bytes(),(observed/"guessed.yml").read_bytes())
                n=isolated("run-native-"+case,(observed/"input").read_bytes(),(native/"config.yml").read_bytes())
                process(java_command(r,jar),r,"run",env);process([str(BINARY),"run","config.yml"],n,"run")
                require(set(outputs(r))=={"result000.00.csv"},"missing expected reference output")
                require(outputs(r)==outputs(n),"transfer bytes mismatch: "+case);entry["transfer"]="matched"
            else:entry["transfer"]="not-claimed: explicit columns required"
        RESULT["cases"].append(entry);print("PIPELINE_CASE="+json.dumps(entry),flush=True)
    for case in ["csv","json-columns","gzip","bzip2"]:
        observed=reference/case
        if case=="json-columns": data=b'{"id":1,"name":"sample payload"}\n'*65536
        else:data=b"id,name\n"+b"1,sample payload\n"*65536
        if case=="gzip":data=gzip.compress(data,mtime=0)
        if case=="bzip2":data=bz2.compress(data)
        sample=(observed/"input").read_bytes()
        decoded_sample=gzip.decompress(sample) if case=="gzip" else bz2.decompress(sample) if case=="bzip2" else sample
        decoded_job=gzip.decompress(data) if case=="gzip" else bz2.decompress(data) if case=="bzip2" else data
        if case=="json-columns":require(set(json.loads(decoded_sample.splitlines()[0]))==set(json.loads(decoded_job.splitlines()[0]))=={"id","name"},"sample/job JSON schema drift")
        else:require(decoded_sample.splitlines()[0]==decoded_job.splitlines()[0]==b"id,name","sample/job CSV schema drift")
        r=isolated("recovery-reference-"+case,data,(observed/"guessed.yml").read_bytes())
        n=isolated("recovery-native-"+case,data,(BASE/("guess-"+case)/"config.yml").read_bytes())
        (n/"guess-sample.bin").write_bytes((observed/"input").read_bytes())
        process(java_command(r,jar),r,"run",env);interrupt(n)
        process([str(BINARY),"resume","config.yml","state"],n,"resume")
        require(set(outputs(r))=={"result000.00.csv"},"missing recovery reference output")
        require(outputs(r)==outputs(n),"recovered bytes mismatch: "+case)
        identities={str(p):p.stat().st_ino for p in (n/"output").iterdir()}
        process([str(BINARY),"resume","config.yml","state"],n,"repeat-resume")
        require(identities=={str(p):p.stat().st_ino for p in (n/"output").iterdir()},"repeat resume replaced target")
        require(outputs(r)==outputs(n),"repeat resume changed output content")
        RESULT["recovery"].append({"case":case,"result":"matched-reference-final-data","sample_sha256":digest(n/"guess-sample.bin"),"job_sha256":digest(n/"input")})
        print("PIPELINE_RECOVERY="+case,flush=True)
    require(digest(BINARY)==RESULT["binary_sha256"],"native binary changed during acceptance")
    RESULT["complete"]=True

try:main()
finally:
    RESULT["files"]=record(BASE)
    (BASE/"summary.json").write_text(json.dumps(RESULT,sort_keys=True)+"\n")
    print("PIPELINE_ROOT="+str(BASE),flush=True)

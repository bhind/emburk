#!/usr/bin/env python3
"""Original black-box guess fixtures with retained, bounded subprocess evidence."""
import bz2
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

JAR_SHA = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
CASES = ("csv", "json", "gzip", "bzip2", "empty", "ambiguous", "headerless", "tsv", "json-columns", "headerless-utf8")
EXPECTED = {
 "csv":"f42d8561eb44f07001e04f1645ecd8fe211f61efc78558b34db45793862dc3eb",
 "json":"5f5b836a335e322c5129c689d2d8b2f5d265f5f83506e79e79445a77fdeb2196",
 "gzip":"54db557ff1b45d887a968992ed2ea6b1bba87efc3fd3251bb1ac64fe79b21824",
 "bzip2":"cfab01bb7a4b5093cad23735030ba8b537c310bbf7a75147b45a42da66502037",
 "empty":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
 "ambiguous":"c8ffa80829a0e5a184d30cc2435f9ec2a7f8c083ca75c777a4fc2c6d8458deee",
 "headerless":"c26073c4f7d1e70911f763841da06be7234fb475ed90706adf3f94f5ebf6dc1e",
 "tsv":"aa043f3520e42ae777d6b335ebb3eeaa6620ac34b1edf52fd685bd7f03f63720",
 "json-columns":"b52875c144ed5fe8865c53091a612f3bf9af897e875d7d3f48d6a4e40be07705",
 "headerless-utf8":"e8a642dabe2109b4c4459956adecddf36019d947a912aebe0619fe518e0ada9b",
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def fixture(case):
    case = {"json-columns":"json", "headerless-utf8":"headerless"}.get(case,case)
    csv = b"id,name\n1,Ada\n2,Bob\n"
    return {"csv":csv, "json":b'{"id":1,"name":"Ada"}\n{"id":2,"name":"Bob"}\n',
            "gzip":gzip.compress(csv,mtime=0), "bzip2":bz2.compress(csv),
            "empty":b"", "ambiguous":b"unstructured prose\nanother sentence\n",
            "headerless":b"1,Ada\n2,Bob\n", "tsv":b"id\tname\n1\tAda\n2\tBob\n"}[case]

def seed(case="csv"):
    base = b'''in:
  type: file
  path_prefix: input
out:
  type: file
  path_prefix: output/result
  file_ext: csv
  formatter:
    type: csv
    charset: UTF-8
    newline: LF
    delimiter: ','
    quote: '"'
    escape: '"'
    header_line: true
    quote_policy: MINIMAL
exec:
  max_threads: 1
  min_output_tasks: 1
'''
    if case=="json-columns":
        base=base.replace(b"out:\n",b"  parser:\n    columns:\n    - {name: id, type: long}\n    - {name: name, type: string}\nout:\n")
    if case=="headerless-utf8":
        base=base.replace(b"out:\n",b"  parser: {charset: UTF-8}\nout:\n")
    return base

def inventory(root):
    result={}
    for name in ("input","seed.yml","stdout.log","stderr.log","guessed.yml","exit.txt"):
        path=root/name
        if path.is_symlink(): raise ValueError("evidence symlink")
        if path.exists():
            data=path.read_bytes(); result[name]={"size":len(data),"sha256":sha(data)}
    return result

def validate(path):
    value=json.loads(path.read_text()); root=path.parent
    if set(value)!={"case","artifact","exit","timeout","files"} or value["case"] not in CASES or value["artifact"]!=JAR_SHA: raise ValueError("manifest contract")
    if type(value["exit"]) is not int or value["timeout"] is not False: raise ValueError("incomplete process")
    if (root/"input").read_bytes()!=fixture(value["case"]) or (root/"seed.yml").read_bytes()!=seed(value["case"]): raise ValueError("fixture drift")
    if (root/"exit.txt").read_text()!=str(value["exit"])+"\n" or inventory(root)!=value["files"]: raise ValueError("evidence drift")
    if value["exit"]==0 and not (root/"guessed.yml").is_file(): raise ValueError("missing guess")
    return value

def run():
    jar=Path(os.environ["EMBURK_REFERENCE_JAR"])
    if jar.is_symlink(): raise ValueError("artifact symlink")
    data=jar.read_bytes()
    if sha(data)!=JAR_SHA: raise ValueError("artifact checksum")
    java=Path(os.environ["JAVA_HOME"])/"bin/java"
    base=Path(tempfile.mkdtemp(prefix="emburk-t0036-guess-"))
    snapshot=base/"embulk.jar"; snapshot.write_bytes(data);snapshot.chmod(0o400)
    env={"PATH":os.defpath,"JAVA_HOME":str(java.parent.parent)}
    version=subprocess.run([str(java),"-version"],env=env,capture_output=True,timeout=10)
    (base/"java-version.txt").write_bytes(version.stdout+version.stderr)
    if version.returncode or b'version "17.' not in version.stderr: raise ValueError("Java17 required")
    outcomes=[]
    for case in CASES:
        root=base/case;root.mkdir();(root/"home").mkdir();(root/"tmp").mkdir();(root/"output").mkdir()
        (root/"input").write_bytes(fixture(case));(root/"seed.yml").write_bytes(seed(case))
        timed_out=False
        with (root/"stdout.log").open("xb") as stdout,(root/"stderr.log").open("xb") as stderr:
            child=subprocess.Popen([str(java),f"-Duser.home={root/'home'}",f"-Djava.io.tmpdir={root/'tmp'}","-jar",str(snapshot),"-X",f"embulk_home={root/'home'}","guess","seed.yml","-o","guessed.yml"],cwd=root,env=env,stdout=stdout,stderr=stderr)
            try: code=child.wait(timeout=60)
            except subprocess.TimeoutExpired:
                child.kill();code=child.wait();timed_out=True
        (root/"exit.txt").write_text(str(code)+"\n")
        value={"case":case,"artifact":JAR_SHA,"exit":code,"timeout":timed_out,"files":inventory(root)}
        manifest=root/"manifest.json";manifest.write_text(json.dumps(value,sort_keys=True)+"\n")
        validate(manifest)
        if code != (1 if case=="empty" else 0) or sha((root/"guessed.yml").read_bytes())!=EXPECTED[case]: raise ValueError("reviewed reference projection changed")
        outcomes.append(value)
        print(f"GUESS_CASE={case}|exit={code}|manifest={manifest}",flush=True)
    (base/"summary.json").write_text(json.dumps(outcomes,sort_keys=True)+"\n")
    print(f"GUESS_ROOT={base}")

if __name__=="__main__":
    if len(sys.argv)==3 and sys.argv[1]=="validate": validate(Path(sys.argv[2]))
    elif len(sys.argv)==1: run()
    else: raise SystemExit("usage: run.py [validate MANIFEST]")

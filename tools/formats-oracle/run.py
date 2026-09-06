#!/usr/bin/env python3
"""Original, retained observations of selected bundled Embulk formats and filters."""
import bz2, gzip, hashlib, json, os, signal, subprocess, sys, tempfile, uuid
from pathlib import Path

JAR_SHA = "e2f298db60c2fe1cc17c377edf7215c7005b5d106d151b1a4278a508e4a32e47"
CASES = ("json-scalars", "gzip-csv", "bzip2-csv", "rename-then-remove", "remove-before-rename")
TIMEOUT = 60

def digest(data): return hashlib.sha256(data).hexdigest()
def detail(path, root):
    path, root = path.resolve(), root.resolve()
    if root not in path.parents: raise ValueError("path escape")
    data = path.read_bytes()
    return {"name": str(path.relative_to(root)), "size": len(data), "sha256": digest(data)}
def write_json(path, value): path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
def pinned_bytes(env):
    value = env.get("EMBURK_REFERENCE_JAR")
    if not value or Path(value).is_symlink() or not Path(value).is_file(): raise ValueError("reference artifact")
    data = Path(value).read_bytes()
    if digest(data) != JAR_SHA: raise ValueError("reference checksum")
    return data
def snapshot(data, root):
    path=root/"embulk.jar"
    with path.open("xb") as stream: stream.write(data)
    path.chmod(0o400)
    if digest(path.read_bytes()) != JAR_SHA: raise ValueError("snapshot checksum")
    return path
def java(env):
    home=env.get("JAVA_HOME"); binary=Path(home or "")/"bin"/"java"
    if not binary.is_file(): raise ValueError("JAVA_HOME")
    result=subprocess.run([str(binary),"-version"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,env={"PATH":os.defpath,"JAVA_HOME":str(Path(home).resolve())},timeout=10)
    raw=result.stdout+result.stderr
    if result.returncode or b'version "17.' not in raw: raise ValueError("Java 17")
    return binary.resolve(),raw
def child_env(root, java_home):
    home=root/"home"; tmp=root/"tmp"; home.mkdir(); tmp.mkdir()
    return {"PATH":os.defpath,"JAVA_HOME":java_home,"EMBULK_HOME":str(home),"HOME":str(home),"TMPDIR":str(tmp)}
def csv_parser(): return b"    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    skip_header_lines: 1\n    columns:\n    - {name: id, type: long}\n    - {name: name, type: string}\n"
def formatter(): return b"    type: csv\n    charset: UTF-8\n    newline: LF\n    delimiter: ','\n    quote: '\"'\n    escape: '\"'\n    header_line: true\n    quote_policy: MINIMAL\n"
def fixture(case):
    plain="id,name\n1,alpha\n2,\"comma, \u2603\"\n".encode("utf-8")
    if case=="json-scalars": return b'{"id":1,"name":"alpha"}\n{"id":2,"name":null}\n{"id":3,"name":""}\n{"id":4,"name":"\xe2\x98\x83"}\n',"input.json"
    if case=="gzip-csv": return gzip.compress(plain,compresslevel=6,mtime=0),"input.csv.gz"
    if case=="bzip2-csv": return bz2.compress(plain,compresslevel=9),"input.csv.bz2"
    return plain,"input.csv"
def config(case):
    input_name=fixture(case)[1]
    if case=="json-scalars": parser=b"    type: json\n    columns:\n    - {name: id, type: long}\n    - {name: name, type: string}\n"
    else: parser=csv_parser()
    decoder=b""
    encoder=b""
    if case=="gzip-csv": decoder=b"  decoders:\n  - {type: gzip}\n"; encoder=b"  encoders:\n  - {type: gzip, level: 6}\n"
    if case=="bzip2-csv": decoder=b"  decoders:\n  - {type: bzip2}\n"; encoder=b"  encoders:\n  - {type: bzip2, level: 9}\n"
    filters=b""
    if case=="rename-then-remove": filters=b"filters:\n- type: rename\n  columns: {name: renamed}\n- type: remove_columns\n  remove: [renamed]\n"
    if case=="remove-before-rename": filters=b"filters:\n- type: remove_columns\n  remove: [renamed]\n- type: rename\n  columns: {name: renamed}\n"
    return b"in:\n  type: file\n  path_prefix: "+input_name.encode()+b"\n"+decoder+b"  parser:\n"+parser+filters+b"out:\n  type: file\n  path_prefix: output/result\n  file_ext: csv\n"+encoder+b"  formatter:\n"+formatter()+b"exec:\n  max_threads: 1\n  min_output_tasks: 1\n"
def inventory(directory):
    result=[]
    for path in sorted(directory.rglob("*")):
        if path.is_symlink(): raise ValueError("inventory symlink")
        if path.is_file(): result.append(detail(path,directory))
    return result
def decode_codec(case, outputs, root):
    decoded=[]
    if case not in {"gzip-csv","bzip2-csv"}: return decoded
    destination=root/"decoded"; destination.mkdir()
    for item in outputs:
        source=root/"output"/item["name"]
        raw=source.read_bytes(); data=gzip.decompress(raw) if case=="gzip-csv" else bz2.decompress(raw)
        target=destination/(Path(item["name"]).name+".decoded"); target.write_bytes(data); decoded.append(detail(target,root))
    return decoded
def decoded_inventory(case, outputs, root):
    result=[]
    for item in outputs:
        raw=(root/"output"/item["name"]).read_bytes()
        data=gzip.decompress(raw) if case=="gzip-csv" else bz2.decompress(raw)
        result.append({"name":"decoded/"+Path(item["name"]).name+".decoded","size":len(data),"sha256":digest(data)})
    return result
def validate(path):
    value=json.loads(path.read_text()); root=path.parent.resolve()
    expected={"case","uuid","artifact","java","input","config","process","outputs","decoded"}
    if set(value)!=expected or value["case"] not in CASES or value["artifact"]!={"sha256":JAR_SHA}: raise ValueError("manifest structure")
    if str(uuid.UUID(value["uuid"]))!=value["uuid"]: raise ValueError("manifest uuid")
    for key in ("java","input","config"):
        item=value[key]; candidate=root/item["name"]
        if not isinstance(item,dict) or set(item)!={"name","size","sha256"} or not candidate.is_file() or detail(candidate,root)!=item: raise ValueError("manifest raw")
    expected_input, expected_name=fixture(value["case"])
    if value["java"]["name"] != "java-version.txt" or value["config"]["name"] != "config.yml" or value["input"]["name"] != expected_name or (root/expected_name).read_bytes() != expected_input: raise ValueError("fixture input")
    if (root/"config.yml").read_bytes() != config(value["case"]): raise ValueError("fixture config")
    process=value["process"]
    if set(process)!={"exit","timed_out","stdout","stderr"} or not isinstance(process["exit"],int) or not isinstance(process["timed_out"],bool): raise ValueError("manifest process")
    for key in ("stdout","stderr"):
        if process[key]["name"] != f"{key}.log" or detail(root/process[key]["name"],root)!=process[key]: raise ValueError("manifest process")
    if (root/"exit.txt").read_text(encoding="ascii") != str(process["exit"])+"\n": raise ValueError("manifest exit")
    if value["outputs"] != inventory(root/"output"): raise ValueError("manifest output")
    decoded=value["decoded"]
    if value["case"] in {"gzip-csv","bzip2-csv"}:
        if not decoded: raise ValueError("manifest decoded")
        for item in decoded:
            if detail(root/item["name"],root)!=item: raise ValueError("manifest decoded")
        if decoded_inventory(value["case"],value["outputs"],root) != decoded: raise ValueError("manifest decoded")
        expected={root/item["name"] for item in decoded}; actual={path for path in (root/"decoded").rglob("*") if path.is_file() or path.is_symlink()}
        if actual != expected or any(path.is_symlink() for path in actual): raise ValueError("manifest decoded")
    elif decoded or (root/"decoded").exists(): raise ValueError("manifest decoded")
    return value
def validate_summary(path):
    value=json.loads(path.read_text()); root=path.parent.resolve()
    if set(value)!={"uuid","artifact_sha256","cases"} or str(uuid.UUID(value["uuid"]))!=value["uuid"] or value["artifact_sha256"]!=JAR_SHA or not isinstance(value["cases"],list): raise ValueError("summary structure")
    seen=set()
    for item in value["cases"]:
        if set(item)!={"case","path","manifest_sha256"} or item["case"] not in CASES or item["case"] in seen: raise ValueError("summary cases")
        case=Path(item["path"])
        if not case.is_absolute() or case.is_symlink() or not case.is_dir() or not str(case).startswith("/private/tmp/"): raise ValueError("summary path")
        manifest=case/"manifest.json"
        if digest(manifest.read_bytes())!=item["manifest_sha256"]: raise ValueError("summary manifest")
        observed=validate(manifest)
        if observed["case"]!=item["case"] or observed["uuid"]!=value["uuid"] or observed["process"]["timed_out"]: raise ValueError("summary manifest")
        seen.add(item["case"])
    if seen!=set(CASES): raise ValueError("summary cases")
    return value
def run_case(case, jar, binary, version, run_uuid):
    root=Path(tempfile.mkdtemp(prefix="emburk-t0014-s02-",dir="/private/tmp")); (root/"output").mkdir()
    input_data,input_name=fixture(case); (root/input_name).write_bytes(input_data); (root/"config.yml").write_bytes(config(case)); (root/"java-version.txt").write_bytes(version)
    env=child_env(root,str(binary.parent.parent)); cmd=[str(binary),f"-Duser.home={env['HOME']}","-jar",str(jar),f"-Xembulk_home={env['EMBULK_HOME']}","run","config.yml"]
    stdout,stderr=root/"stdout.log",root/"stderr.log"
    with stdout.open("xb") as out,stderr.open("xb") as err:
        process=subprocess.Popen(cmd,cwd=root,env=env,stdout=out,stderr=err,start_new_session=True); timed=False
        try: code=process.wait(timeout=TIMEOUT)
        except subprocess.TimeoutExpired: timed=True; os.killpg(process.pid,signal.SIGKILL); code=process.wait()
    (root/"exit.txt").write_text(str(code)+"\n",encoding="ascii")
    outputs=inventory(root/"output"); decoded=decode_codec(case,outputs,root)
    value={"case":case,"uuid":run_uuid,"artifact":{"sha256":JAR_SHA},"java":detail(root/"java-version.txt",root),"input":detail(root/input_name,root),"config":detail(root/"config.yml",root),"process":{"exit":code,"timed_out":timed,"stdout":detail(stdout,root),"stderr":detail(stderr,root)},"outputs":outputs,"decoded":decoded}
    write_json(root/"manifest.json",value); validate(root/"manifest.json")
    print(f"T0014_S02_CASE={case}|exit={code}|timed_out={str(timed).lower()}|evidence={root}",flush=True); return root
def main():
    run=Path(tempfile.mkdtemp(prefix="emburk-t0014-s02-run-",dir="/private/tmp")); jar=snapshot(pinned_bytes(dict(os.environ)),run); binary,version=java(dict(os.environ)); run_uuid=str(uuid.uuid4()); cases=[]
    for case in CASES:
        root=run_case(case,jar,binary,version,run_uuid); cases.append({"case":case,"path":str(root),"manifest_sha256":digest((root/"manifest.json").read_bytes())})
    write_json(run/"manifest.json",{"uuid":run_uuid,"artifact_sha256":JAR_SHA,"cases":cases}); validate_summary(run/"manifest.json"); print(f"T0014_S02_EVIDENCE_DIR={run}"); return 0
if __name__=="__main__":
    try: raise SystemExit(main())
    except (OSError,ValueError,subprocess.SubprocessError) as error: print(f"T0014_S02_CAPTURE_ERROR={error}",file=sys.stderr); raise SystemExit(2)

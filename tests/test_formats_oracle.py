import gzip, importlib.util, json, tempfile, unittest
from pathlib import Path
from unittest import mock
ROOT=Path(__file__).resolve().parents[1]; spec=importlib.util.spec_from_file_location("oracle",ROOT/"tools/formats-oracle/run.py"); oracle=importlib.util.module_from_spec(spec); spec.loader.exec_module(oracle)
class FormatsOracleTests(unittest.TestCase):
 def valid(self,d,case="json-scalars"):
  root=Path(d); (root/"output").mkdir(); data,name=oracle.fixture(case); (root/name).write_bytes(data); (root/"config.yml").write_bytes(oracle.config(case)); (root/"java-version.txt").write_bytes(b"17\n"); (root/"stdout.log").write_bytes(b""); (root/"stderr.log").write_bytes(b""); (root/"exit.txt").write_text("0\n")
  val={"case":case,"uuid":"00000000-0000-4000-8000-000000000000","artifact":{"sha256":oracle.JAR_SHA},"java":oracle.detail(root/"java-version.txt",root),"input":oracle.detail(root/name,root),"config":oracle.detail(root/"config.yml",root),"process":{"exit":0,"timed_out":False,"stdout":oracle.detail(root/"stdout.log",root),"stderr":oracle.detail(root/"stderr.log",root)},"outputs":[],"decoded":[]}; p=root/"manifest.json"; p.write_text(json.dumps(val,sort_keys=True)+"\n"); return p,val
 def test_fixture_profiles_are_explicit(self):
  self.assertEqual(set(oracle.CASES),{"json-scalars","gzip-csv","bzip2-csv","rename-then-remove","remove-before-rename"}); self.assertIn(b"max_threads: 1",oracle.config("gzip-csv")); self.assertIn(b"type: json",oracle.config("json-scalars")); self.assertIn(b"columns: {name: renamed}",oracle.config("rename-then-remove")); self.assertIn(b"remove: [renamed]",oracle.config("remove-before-rename")); self.assertEqual(oracle.fixture("gzip-csv"),oracle.fixture("gzip-csv"))
 def test_wrong_artifact(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/"bad"; p.write_bytes(b"bad")
   with self.assertRaises(ValueError): oracle.pinned_bytes({"EMBURK_REFERENCE_JAR":str(p)})
 def test_manifest_raw_controls(self):
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); oracle.validate(p); (Path(d)/"config.yml").write_bytes(b"changed")
   with self.assertRaises(ValueError): oracle.validate(p)
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); name=oracle.fixture("json-scalars")[1]; (Path(d)/name).write_bytes(b"changed")
   with self.assertRaises(ValueError): oracle.validate(p)
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); v["process"]["exit"]=1; p.write_text(json.dumps(v))
   with self.assertRaises(ValueError): oracle.validate(p)
 def test_extra_missing_and_path_controls(self):
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); (Path(d)/"output"/"extra.csv").write_bytes(b"x")
   with self.assertRaises(ValueError): oracle.validate(p)
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); v["config"]["name"]="../escape"; p.write_text(json.dumps(v))
   with self.assertRaises(ValueError): oracle.validate(p)
 def test_timeout_is_retained_not_success(self):
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); v["process"]["timed_out"]=True; p.write_text(json.dumps(v)); self.assertTrue(oracle.validate(p)["process"]["timed_out"])
 def test_codec_decoded_control(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d); (root/"output").mkdir(); raw=gzip.compress(b"id,name\n"); (root/"output"/"result.csv").write_bytes(raw); (root/"decoded").mkdir(); (root/"decoded"/"result.csv.decoded").write_bytes(b"id,name\n")
   data,name=oracle.fixture("gzip-csv"); (root/name).write_bytes(data); (root/"config.yml").write_bytes(oracle.config("gzip-csv")); (root/"java-version.txt").write_bytes(b"17"); (root/"stdout.log").write_bytes(b""); (root/"stderr.log").write_bytes(b""); (root/"exit.txt").write_text("0\n")
   v={"case":"gzip-csv","uuid":"00000000-0000-4000-8000-000000000000","artifact":{"sha256":oracle.JAR_SHA},"java":oracle.detail(root/"java-version.txt",root),"input":oracle.detail(root/name,root),"config":oracle.detail(root/"config.yml",root),"process":{"exit":0,"timed_out":False,"stdout":oracle.detail(root/"stdout.log",root),"stderr":oracle.detail(root/"stderr.log",root)},"outputs":oracle.inventory(root/"output"),"decoded":[oracle.detail(root/"decoded"/"result.csv.decoded",root)]}; p=root/"manifest.json"; p.write_text(json.dumps(v)); oracle.validate(p); (root/"decoded"/"result.csv.decoded").write_bytes(b"changed")
   with self.assertRaises(ValueError): oracle.validate(p)
 def test_exact_fixture_byte_controls(self):
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); changed=oracle.config("json-scalars")+b"# changed\n"; (Path(d)/"config.yml").write_bytes(changed); v["config"]["size"]=len(changed); v["config"]["sha256"]=oracle.digest(changed); p.write_text(json.dumps(v))
   with self.assertRaises(ValueError): oracle.validate(p)
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); name=oracle.fixture("json-scalars")[1]; changed=b"changed"; (Path(d)/name).write_bytes(changed); v["input"]["size"]=len(changed); v["input"]["sha256"]=oracle.digest(changed); p.write_text(json.dumps(v))
   with self.assertRaises(ValueError): oracle.validate(p)
 def test_output_symlink_and_decoded_extra_controls(self):
  with tempfile.TemporaryDirectory() as d:
   p,v=self.valid(d); (Path(d)/"output"/"link").symlink_to(Path(d)/"output")
   with self.assertRaises(ValueError): oracle.validate(p)
  with tempfile.TemporaryDirectory() as d:
   root=Path(d); (root/"output").mkdir(); raw=gzip.compress(b"id,name\n"); (root/"output"/"result.csv").write_bytes(raw); (root/"decoded").mkdir(); (root/"decoded"/"result.csv.decoded").write_bytes(b"id,name\n")
   data,name=oracle.fixture("gzip-csv"); (root/name).write_bytes(data); (root/"config.yml").write_bytes(oracle.config("gzip-csv")); (root/"java-version.txt").write_bytes(b"17"); (root/"stdout.log").write_bytes(b""); (root/"stderr.log").write_bytes(b""); (root/"exit.txt").write_text("0\n")
   v={"case":"gzip-csv","uuid":"00000000-0000-4000-8000-000000000000","artifact":{"sha256":oracle.JAR_SHA},"java":oracle.detail(root/"java-version.txt",root),"input":oracle.detail(root/name,root),"config":oracle.detail(root/"config.yml",root),"process":{"exit":0,"timed_out":False,"stdout":oracle.detail(root/"stdout.log",root),"stderr":oracle.detail(root/"stderr.log",root)},"outputs":oracle.inventory(root/"output"),"decoded":[oracle.detail(root/"decoded"/"result.csv.decoded",root)]}; p=root/"manifest.json"; p.write_text(json.dumps(v)); oracle.validate(p); (root/"decoded"/"extra").write_bytes(b"x")
   with self.assertRaises(ValueError): oracle.validate(p)
 def test_summary_missing_extra_duplicate_uuid_and_timeout_controls(self):
  with tempfile.TemporaryDirectory(dir="/private/tmp") as d:
   root=Path(d); run_uuid="00000000-0000-4000-8000-000000000000"; entries=[]
   for case in oracle.CASES:
    item=root/case; item.mkdir(); manifest=item/"manifest.json"; manifest.write_bytes(case.encode()); entries.append({"case":case,"path":str(item),"manifest_sha256":oracle.digest(manifest.read_bytes())})
   summary=root/"summary.json"
   def observed(manifest): return {"case":manifest.parent.name,"uuid":run_uuid,"process":{"timed_out":False}}
   with mock.patch.object(oracle,"validate",side_effect=observed):
    summary.write_text(json.dumps({"uuid":run_uuid,"artifact_sha256":oracle.JAR_SHA,"cases":entries})); oracle.validate_summary(summary)
    for changed in (entries[:-1], entries+[entries[0]]):
     summary.write_text(json.dumps({"uuid":run_uuid,"artifact_sha256":oracle.JAR_SHA,"cases":changed}))
     with self.assertRaises(ValueError): oracle.validate_summary(summary)
    def wrong_uuid(manifest): return {"case":manifest.parent.name,"uuid":"00000000-0000-4000-8000-000000000001","process":{"timed_out":False}}
    with mock.patch.object(oracle,"validate",side_effect=wrong_uuid):
     summary.write_text(json.dumps({"uuid":run_uuid,"artifact_sha256":oracle.JAR_SHA,"cases":entries}))
     with self.assertRaises(ValueError): oracle.validate_summary(summary)
    def timed(manifest): return {"case":manifest.parent.name,"uuid":run_uuid,"process":{"timed_out":True}}
    with mock.patch.object(oracle,"validate",side_effect=timed):
     with self.assertRaises(ValueError): oracle.validate_summary(summary)
if __name__=="__main__": unittest.main()

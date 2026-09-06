import importlib.util
from pathlib import Path
import tempfile
import unittest
import json

spec=importlib.util.spec_from_file_location("guess_oracle",Path(__file__).parents[1]/"tools/guess-oracle/run.py")
oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)

class GuessOracleTest(unittest.TestCase):
    def evidence(self):
        root=Path(tempfile.mkdtemp(prefix="emburk-guess-validator-"))
        for name,data in {"input":oracle.fixture("csv"),"seed.yml":oracle.seed(),"stdout.log":b"","stderr.log":b"","guessed.yml":b"in: {}\n","exit.txt":b"0\n"}.items(): (root/name).write_bytes(data)
        value={"case":"csv","artifact":oracle.JAR_SHA,"exit":0,"timeout":False,"files":oracle.inventory(root)}
        path=root/"manifest.json";path.write_text(json.dumps(value));return root,path,value
    def test_valid(self):
        _,path,_=self.evidence();oracle.validate(path)
    def test_modified_input_rejected_even_with_rehashed_manifest(self):
        root,path,value=self.evidence();(root/"input").write_bytes(b"changed");value["files"]=oracle.inventory(root);path.write_text(json.dumps(value))
        with self.assertRaises(ValueError):oracle.validate(path)
    def test_timeout_missing_output_and_exit_drift_rejected(self):
        for kind in ["timeout","missing","exit"]:
            root,path,value=self.evidence()
            if kind=="timeout":value["timeout"]=True
            elif kind=="missing":(root/"guessed.yml").unlink();value["files"]=oracle.inventory(root)
            else:(root/"exit.txt").write_text("1\n");value["files"]=oracle.inventory(root)
            path.write_text(json.dumps(value))
            with self.assertRaises(ValueError):oracle.validate(path)

if __name__=="__main__":unittest.main()

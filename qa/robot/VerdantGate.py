import os
import re
import shutil
import subprocess


class VerdantGate:
    ROBOT_LIBRARY_SCOPE = "SUITE"

    def __init__(self, root=None):
        here = os.path.dirname(os.path.abspath(__file__))
        self.root = os.path.abspath(root or os.path.join(here, "..", ".."))
        self.lua = shutil.which("lua") or shutil.which("lua5.4") or "lua"
        self.luac = shutil.which("luac") or shutil.which("luac5.4") or "luac"

    def _run(self, args, cwd=None, timeout=600):
        proc = subprocess.run(args, cwd=cwd or self.root, capture_output=True, text=True, timeout=timeout)
        return proc.returncode, (proc.stdout or "") + (proc.stderr or "")

    def repo_root(self):
        return self.root

    def every_lua_file_parses(self):
        bad = []
        for dirpath, dirnames, filenames in os.walk(self.root):
            dirnames[:] = [d for d in dirnames if d not in (".git", ".lake", "output")]
            for f in filenames:
                if f.endswith(".lua"):
                    code, _ = self._run([self.luac, "-p", os.path.join(dirpath, f)])
                    if code != 0:
                        bad.append(os.path.relpath(os.path.join(dirpath, f), self.root))
        if bad:
            raise AssertionError("files that do not parse: " + ", ".join(bad))
        return "all lua files parse"

    def harness_passes(self, debug="1"):
        code, out = self._run([self.lua, "test/harness/run.lua", ".", str(debug)])
        last = out.strip().splitlines()[-1] if out.strip() else ""
        m = re.search(r"== (\d+) passed, (\d+) failed", last)
        if not m or int(m.group(2)) != 0 or code != 0:
            fails = [l for l in out.splitlines() if l.startswith("FAIL") or l.startswith("      ")]
            raise AssertionError("harness failed: " + last + "\n" + "\n".join(fails))
        return "%s cases passed (DEBUG=%s)" % (m.group(1), debug)

    def simlab_scenarios_pass(self):
        code, out = self._run([self.lua, "test/simlab/run.lua", ".", "--svg"])
        passed = len(re.findall(r"^PASS", out, re.M))
        failed = [l for l in out.splitlines() if l.startswith("FAIL")]
        if failed or passed < 3:
            raise AssertionError("simlab: %d passed, failures: %s" % (passed, failed))
        return "%d scenarios agree with the oracle" % passed

    def simlab_mockups_render(self):
        code, out = self._run([self.lua, "test/simlab/mockups.lua", "."])
        if code != 0:
            raise AssertionError("mockups failed:\n" + out[-2000:])
        return "mockups rendered"

    def layout_audit_is_clean(self):
        code, out = self._run([self.lua, "test/simlab/audit.lua", "."])
        last = out.strip().splitlines()[-1] if out.strip() else ""
        m = re.search(r"audit: (\d+) finding", last)
        if not m or int(m.group(1)) != 0:
            raise AssertionError("layout audit: " + last + "\n" + out[-3000:])
        return "0 layout findings"

    def replay_audits_are_clean(self, traces_dir=None):
        traces = traces_dir or os.path.join(self.root, "..", "VerdantWorkingdir", "traces")
        traces = os.path.abspath(traces)
        if not os.path.isdir(traces):
            return "no traces directory at %s, nothing replayed" % traces
        replayed = 0
        for f in sorted(os.listdir(traces)):
            if not f.endswith(".lua"):
                continue
            code, out = self._run([self.lua, "test/simlab/replay.lua", ".", os.path.join(traces, f)])
            if code != 0:
                raise AssertionError("replay %s failed:\n%s" % (f, out[-2000:]))
            code, out = self._run([self.lua, "test/simlab/audit.lua", "."])
            last = out.strip().splitlines()[-1] if out.strip() else ""
            m = re.search(r"audit: (\d+) finding", last)
            if not m or int(m.group(1)) != 0:
                raise AssertionError("replay %s layout audit: %s" % (f, last))
            replayed += 1
        return "%d traces replayed and audited clean" % replayed

    def live_equals_library(self):
        code, out = self._run([self.lua, "test/simlab/reina.lua", "."])
        diffs = [l for l in out.splitlines() if "FAIL" in l]
        if diffs or code != 0:
            raise AssertionError("live vs library differ:\n" + "\n".join(diffs) + "\n" + out[-1500:])
        views = len(re.findall(r"IDENTICAL", out))
        return "%d views identical live and loaded" % views

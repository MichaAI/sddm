"""Run with prepared bento-boot frames: python3 tests/test-handoff.py FRAMES."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

frames = Path(sys.argv[1]).resolve()
count = int((frames / "count").read_text())
harness = Path(__file__).with_name("handoff.qml").resolve()
env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QML_XHR_ALLOW_FILE_READ="1")
with tempfile.TemporaryDirectory(prefix="bento-handoff-") as directory:
    state = Path(directory) / "state.json"
    for case in ("valid", "stale", "future", "malformed", "missing", "missing-frames"):
        value = dict(version=1, savedAt=int(time.time() * 1000), frame=min(25, count - 1), x=0.5, y=0.53, size=0.3)
        if case == "stale":
            value["savedAt"] -= 60000
        if case == "future":
            value["savedAt"] += 60000
        state.write_text("{broken" if case == "malformed" else json.dumps(value))
        if case == "missing":
            state.unlink()
        params = dict(frames=(Path(directory) if case == "missing-frames" else frames).as_uri(),
                      state=state.as_uri(), count=count, expected=case == "valid")
        subprocess.run(["qml", str(harness), json.dumps(params)], env=env, check=True, timeout=15)
        print(f"{case}: passed", flush=True)

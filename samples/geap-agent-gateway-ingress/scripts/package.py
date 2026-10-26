"""Build a deterministic tar.gz of app/ for Terraform's source_code_spec.inline_source.

Fixed mtime/uid/gid/mode and sorted entries: identical sources always give identical bytes,
so Terraform never shows a spurious diff. Files sit at the archive root, as Agent Runtime expects.
"""

import gzip
import io
import sys
import tarfile
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent.parent / "app"
DEFAULT_OUTPUT = Path(__file__).resolve().parent.parent / "build" / "agent_src.tar.gz"
EXCLUDED_PARTS = {"__pycache__", ".pytest_cache", ".venv"}


def build_archive(app_dir: Path, output: Path) -> Path:
    """Write the archive and return its path."""
    files = sorted(
        p for p in app_dir.rglob("*") if p.is_file() and not EXCLUDED_PARTS & set(p.parts) and p.suffix != ".pyc"
    )
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for path in files:
            info = tarfile.TarInfo(name=path.relative_to(app_dir).as_posix())
            data = path.read_bytes()
            info.size = len(data)
            info.mtime = 0
            info.mode = 0o644
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            tar.addfile(info, io.BytesIO(data))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as gz:
        gz.write(buffer.getvalue())
    return output


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    print(build_archive(APP_DIR, out))

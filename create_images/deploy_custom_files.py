#!/usr/bin/env python3
"""
deploy_image_files.py

Loop-mounts a multiboot image file, detects the OS and version, then copies
the appropriate custom files from the local custom_files/ directory tree to
the image's parent directory, prefixed with the image name.

Usage:
    sudo python3 deploy_image_files.py /path/to/image.img

Requirements:
    - Must be run as root (uses losetup, mount)
    - losetup, mount/umount must be available
    - custom_files/ directory must exist alongside this script
"""

import os
import sys
import shutil
import signal
import subprocess
import tempfile
import re
import configparser
from pathlib import Path


# ---------------------------------------------------------------------------
# Cleanup registry
# ---------------------------------------------------------------------------

class CleanupManager:
    """Tracks all resources that must be released on exit, in reverse order."""

    def __init__(self):
        self._mounts = []       # directories currently bind/loop mounted
        self._tempdirs = []     # temp directories we created
        self._loopdevs = []     # loop devices created with losetup

    def register_mount(self, path: str):
        self._mounts.append(path)

    def register_tempdir(self, path: str):
        self._tempdirs.append(path)

    def register_loopdev(self, dev: str):
        self._loopdevs.append(dev)

    def cleanup(self, label: str = ""):
        if label:
            vprint(5,f"\n[cleanup] {label}")

        # Unmount in reverse registration order
        for mnt in reversed(self._mounts):
            if os.path.ismount(mnt):
                _run(["umount", "-l", mnt], check=False, silent=True)
        self._mounts.clear()

        # Remove temp dirs
        for d in reversed(self._tempdirs):
            if os.path.exists(d):
                try:
                    os.rmdir(d)
                except OSError:
                    shutil.rmtree(d, ignore_errors=True)
        self._tempdirs.clear()

        # Detach loop devices
        for dev in reversed(self._loopdevs):
            _run(["losetup", "-d", dev], check=False, silent=True)
        self._loopdevs.clear()


_cleanup = CleanupManager()


def _signal_handler(sig, frame):
    _cleanup.cleanup(label=f"Caught signal {sig}, cleaning up")
    sys.exit(1)


signal.signal(signal.SIGINT, _signal_handler)
signal.signal(signal.SIGTERM, _signal_handler)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(cmd: list, check: bool = True, silent: bool = False,
         capture: bool = False):
    """Run a subprocess, optionally capturing output."""
    kwargs = dict(
        check=check,
        stdout=subprocess.PIPE if capture or silent else None,
        stderr=subprocess.PIPE if silent else None,
    )
    try:
        result = subprocess.run(cmd, **kwargs)
        return result
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return e


def _read_os_release(root: str) -> dict:
    """Parse /etc/os-release from the given root. Returns a dict or {}."""
    candidates = [
        os.path.join(root, "etc", "os-release"),
        os.path.join(root, "root", "etc", "os-release"),
        os.path.join(root, "usr", "lib", "os-release"),
        os.path.join(root, "root", "usr", "lib", "os-release"),
    ]
    for path in candidates:
        if os.path.isfile(path):
            parser = configparser.ConfigParser()
            try:
                with open(path) as f:
                    content = "[os]\n" + f.read()
                parser.read_string(content)
                return {k.upper(): v.strip('"\'') for k, v in parser["os"].items()}
            except Exception:
                continue
    return {}


def _read_build_prop(root: str) -> dict:
    """
    Parse build.prop from an Android system-as-root layout.
    The file lives at <root>/build.prop (system-as-root on Pi).
    Falls back to <root>/system/build.prop for non-SAR layouts.
    Returns a dict of key=value pairs.
    """
    candidates = [
        os.path.join(root, "build.prop"),
        os.path.join(root, "system", "build.prop"),
    ]
    for path in candidates:
        if os.path.isfile(path):
            props = {}
            try:
                with open(path) as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, _, v = line.partition("=")
                            props[k.strip()] = v.strip()
            except Exception:
                pass
            return props
    return {}


def _has_raspi_list(root: str) -> bool:
    return (
        os.path.isfile(os.path.join(root, "etc", "apt", "sources.list.d", "raspi.list")) or
        os.path.isfile(os.path.join(root, "etc", "apt", "sources.list.d", "raspi.sources")) or
        os.path.isfile(os.path.join(root, "var", "lib", "dpkg", "info", "raspi-config.list"))
    )


def _get_partition_uuids(loopdev: str) -> list:
    """
    Return an ordered list of UUIDs for all partitions on loopdev.
    Index 0 = partition 1, index 1 = partition 2, etc.
    None is stored for any partition with no UUID (e.g. FAT without one).
    """
    uuids = []
    for part in _get_loop_partitions(loopdev):
        result = _run(
            ["blkid", "-s", "UUID", "-o", "value", part],
            check=False, capture=True, silent=True
        )
        if result.returncode == 0:
            uuid = result.stdout.decode().strip() or None
        else:
            uuid = None
        uuids.append(uuid)
    return uuids

# ---------------------------------------------------------------------------
# Partition scanning
# ---------------------------------------------------------------------------

def _get_loop_partitions(loopdev: str) -> list:
    """
    Return sorted list of partition device paths for a loopback device,
    e.g. ['/dev/loop0p1', '/dev/loop0p2', ...].
    """
    base = os.path.basename(loopdev)  # e.g. loop0
    parts = sorted(Path("/dev").glob(f"{base}p*"))
    return [str(p) for p in parts]


def _try_mount(partition: str, mountpoint: str) -> bool:
    """Attempt to mount a partition. Returns True on success."""
    result = _run(
        ["mount", "-o", "ro", partition, mountpoint],
        check=False, silent=True
    )
    return result.returncode == 0


def _not_found() -> dict:
    """Standard not-found result."""
    return {"found": False, "os_name": "", "version": "0",
            "version_f": 0.0, "uuids": []}


def _detect_linux(mntdir: str, uuids: list) -> dict:
    """
    Try to detect a Linux OS via os-release.
    Returns a result dict with found=True on success, found=False otherwise.
    """
    vprint(4,f"[detect] Checking for a Linux ")

    osrel = _read_os_release(mntdir)
    if not osrel:
        return _not_found()

    os_id = osrel.get("ID", "linux").lower()
    version = osrel.get("VERSION_ID", "0").split(".")[0]

    if os_id == "debian" and _has_raspi_list(mntdir):
        os_id = "raspbian"
        vprint(3,f"[detect] Detected raspbian (debian + raspi.list)")

    vprint(3,f"[detect] OS: {os_id}, VERSION_ID: {version}")

    try:
        version_f = float(version)
    except ValueError:
        vprint(3,f"[detect] Version unreadable, defaulting to 0")
        version_f = 0.0

    return {"found": True, "os_name": os_id, "version": version,
            "version_f": version_f, "uuids": uuids}


def _detect_android(mntdir: str, uuids: list) -> dict:
    """
    Try to detect Android / LineageOS via build.prop.
    Returns a result dict with found=True on success, found=False otherwise.
    """
    vprint(4,f"[detect] Checking for Android (Lineage)")
    props = _read_build_prop(mntdir)
    if not props:
        return _not_found()

    os_name_raw = props.get("ro.build.flavor",
                  props.get("ro.product.name", "android")).lower()
    version = props.get("ro.build.version.release", "0").split(".")[0]

    os_id = "lineage" if ("lineage" in os_name_raw or
                          "lineageos" in os_name_raw) else "android"

    vprint(3,f"[detect] OS: {os_id} (Android), version: {version}")

    try:
        version_f = float(version)
    except ValueError:
        vprint(3,f"[detect] Version unreadable, defaulting to 0")
        version_f = 0.0

    return {"found": True, "os_name": os_id, "version": version,
            "version_f": version_f, "uuids": uuids}


def _detect_libreelec(mntdir: str, uuids: list) -> dict:
    """
    Detect LibreELEC by scanning the SYSTEM squashfs binary for a version
    string. Reads in chunks and stops as soon as the pattern is found,
    avoiding a full 100MB+ scan in the common case.
    Returns a result dict with found=True on success, found=False otherwise.
    """
    vprint(4,f"[detect] Checking for LibreELEC")

    system_path = os.path.join(mntdir, "SYSTEM")
    if not os.path.isfile(system_path):
        return _not_found()

    vprint(5,f"[detect] Found SYSTEM file, scanning for LibreELEC version...")

    pattern    = b'LibreELEC'
    version_re = re.compile(rb'LibreELEC-[\w.]+\.-?(\d+\.\d+(?:\.\d+)?)')
    chunk_size = 1024 * 1024   # 1 MB
    overlap    = 64            # carry-over to catch boundary splits

    prev = b''
    with open(system_path, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            data = prev + chunk
            if pattern in data:
                m = version_re.search(data)
                if m:
                    version = m.group(1).decode()
                    version_major = version.split(".")[0]
                    vprint(3,f"[detect] LibreELEC version string: {version}")
                    try:
                        version_f = float(version_major)
                    except ValueError:
                        version_f = 0.0
                    return {"found": True, "os_name": "libreelec",
                            "version": version_major, "version_f": version_f,
                            "uuids": uuids}
            prev = chunk[-overlap:]

    # SYSTEM file found but version unreadable — still LibreELEC
    vprint(3,f"[detect] Version unreadable, defaulting to 0")
    return {"found": True, "os_name": "libreelec", "version": "0",
            "version_f": 0.0, "uuids": uuids}


def detect_os(loopdev: str, cleanup: CleanupManager) -> dict:
    """
    Iterate through partitions on loopdev, trying each detector in order.
    Returns a dict with keys: os_name, version, version_f, uuids, found.
    Raises RuntimeError if no partition is recognised.
    """
    partitions = _get_loop_partitions(loopdev)
    if not partitions:
        raise RuntimeError(f"No partitions found on {loopdev}")

    vprint(5,f"[detect] Found partitions: {', '.join(partitions)}")

    # Gather all UUIDs once upfront — passed to whichever detector succeeds
    uuids = _get_partition_uuids(loopdev)
    vprint(4,f"[detect] Partition UUIDs: {uuids}")

    detectors = [_detect_linux, _detect_android, _detect_libreelec]

    for part in partitions:
        mntdir = tempfile.mkdtemp(prefix="multiboot_probe_")
        cleanup.register_tempdir(mntdir)

        if not _try_mount(part, mntdir):
            os.rmdir(mntdir)
            cleanup._tempdirs.remove(mntdir)
            continue

        cleanup.register_mount(mntdir)
        vprint(5,f"[detect] Mounted {part} → {mntdir}")

        for detector in detectors:
            result = detector(mntdir, uuids)
            if result["found"]:
                _run(["umount", mntdir], check=False, silent=True)
                cleanup._mounts.remove(mntdir)
                os.rmdir(mntdir)
                cleanup._tempdirs.remove(mntdir)
                return result

        # Nothing found on this partition — unmount and move on
        _run(["umount", mntdir], check=False, silent=True)
        cleanup._mounts.remove(mntdir)
        os.rmdir(mntdir)
        cleanup._tempdirs.remove(mntdir)

    raise RuntimeError("Could not detect OS from any partition in the image.")


# ---------------------------------------------------------------------------
# Version bracket selection
# ---------------------------------------------------------------------------

def _parse_version_dirs(os_dir: Path) -> list:
    """
    Scan os_dir for subdirectories matching '<number>+' (integer or decimal).
    Returns a list of (threshold_float, Path) sorted ascending by threshold.
    """
    pattern = re.compile(r'^(\d+(?:\.\d+)?)\+$')
    entries = []
    for child in os_dir.iterdir():
        if child.is_dir():
            m = pattern.match(child.name)
            if m:
                entries.append((float(m.group(1)), child))
    entries.sort(key=lambda x: x[0])
    return entries


def find_version_dir(custom_files_root: Path, os_name: str,
                     version_f: float) -> Path:
    """
    Return the Path of the best-matching version directory for the given OS
    and version float, or raise FileNotFoundError.

    Logic: highest threshold that is <= version_f wins.
    E.g. dirs [0+, 22+, 26+] and version 24 → 22+ wins.
         dirs [0+, 22+, 26+] and version 26 → 26+ wins.
         dirs [0+, 22+, 26+] and version 10 → 0+  wins.
    """
    os_dir = custom_files_root / os_name.lower()
    if not os_dir.is_dir():
        raise FileNotFoundError(
            f"No custom_files directory for OS '{os_name}' at {os_dir}"
        )

    brackets = _parse_version_dirs(os_dir)
    if not brackets:
        raise FileNotFoundError(
            f"No version directories (e.g. '0+') found in {os_dir}"
        )

    selected = None
    for threshold, path in brackets:
        if version_f >= threshold:
            selected = path
        else:
            break  # sorted ascending, no point continuing

    if selected is None:
        raise FileNotFoundError(
            f"Version {version_f} is below the lowest bracket "
            f"{brackets[0][0]}+ in {os_dir}"
        )

    return selected


# ---------------------------------------------------------------------------
# File deployment
# ---------------------------------------------------------------------------

def deploy_files(version_dir: Path, image_path: str, image_name: str,
                 uuids: list = []):
    """
    Copy every file from version_dir into image_path, prefixing each
    filename with '<image_name>'. Files named 'osname.*' get just the
    extension appended; all others get '_filename' appended.
    Grub files have <osname> and <osname_UUID_N> (1-based) substituted.
    """
    files = [f for f in version_dir.iterdir() if f.is_file()]
    if not files:
        vprint(3,f"[deploy] Warning: no files found in {version_dir}")
        return()

    dest_dir = Path(image_path)
    dest_dir.mkdir(parents=True, exist_ok=True)

    for src in files:
        dest_name = f"{image_name}{src.name.removeprefix('osname')}"
        dest = dest_dir / dest_name

        if "grub" in src.name.lower():
            content = src.read_text()
            content = content.replace("<osname>", image_name)
            subs = ["<osname>"]
            for i, uuid in enumerate(uuids, start=1):
                placeholder = f"<osname_UUID_{i}>"
                if uuid and placeholder in content:
                    content = content.replace(placeholder, uuid)
                    subs.append(placeholder)
            vprint(5,f"[deploy] {src.name} → {dest} "
                  f"(substituted: {', '.join(subs)})")
            dest.write_text(content)
        else:
            vprint(5,f"[deploy] {src.name} → {dest}")
            shutil.copy2(src, dest)

    vprint(2,f"[deploy] Deployed {len(files)} file(s) to {dest_dir}")


def vprint(level: int, *args, stream=sys.stdout, **kwargs):
    if level > verbosity:
        return
    print(*args, file=stream, **kwargs)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
verbosity = 3  # default
def main():
    global verbosity
    for arg in sys.argv[1:]:
        if arg.startswith("-v") and len(arg) > 2 and arg[2:].isdigit():
            verbosity = int(arg[2:])
            sys.argv.remove(arg)
            break

    if os.geteuid() != 0:
        vprint(1,"Error: this script must be run as root (sudo).", stream=sys.stderr)
        sys.exit(1)

    if len(sys.argv) != 2:
        vprint(2,f"Usage: sudo {sys.argv[0]} -v[0..5] /path/to/image.img", stream=sys.stderr)
        sys.exit(1)

    img_file = sys.argv[1]

    if not os.path.isfile(img_file):
        vprint(1,f"Error: image file not found: {img_file}", stream=sys.stderr)
        sys.exit(1)

    # --- Derive imagepath and imagename ---
    img_file      = os.path.abspath(img_file)
    image_path    = os.path.dirname(img_file)
    image_name    = Path(img_file).stem          # filename without extension
    script_dir    = Path(__file__).resolve().parent
    custom_files  = script_dir / "custom_files"

    vprint(5,f"[init] Image  : {img_file}")
    vprint(5,f"[init] Path   : {image_path}")
    vprint(5,f"[init] Name   : {image_name}")
    vprint(5,f"[init] Scripts: {script_dir}")

    if not custom_files.is_dir():
        vprint(1,f"Error: custom_files directory not found at {custom_files}",
              stream=sys.stderr)
        sys.exit(1)

    # --- Loop-mount the image ---
    try:
        result = _run(
            ["losetup", "--find", "--partscan", "--show", img_file],
            capture=True
        )
        loopdev = result.stdout.decode().strip()
    except subprocess.CalledProcessError as e:
        vprint(1,f"Error: losetup failed: {e}", stream=sys.stderr)
        sys.exit(1)

    _cleanup.register_loopdev(loopdev)
    vprint(5,f"[loop] Attached {img_file} → {loopdev}")

    try:
        # --- Detect OS ---
        info = detect_os(loopdev, _cleanup)
        vprint(2,f"[info] OS={info['os_name']}  version={info['version']}  "
              f"(numeric {info['version_f']})")
        vprint(2,f"[info] UUIDs: { {i+1: u for i, u in enumerate(info['uuids'])} }")

        # --- Find matching version directory ---
        version_dir = find_version_dir(custom_files, info["os_name"],
                                       info["version_f"])
        vprint(3,f"[match] Using files from: {version_dir}")

        # --- Confirm before deploying ---
        if verbosity >= 3:
            vprint(3,f"\n  Custom files from : {version_dir}")
            vprint(3,f"  Will be copied to : {image_path}")
            vprint(3,f"  Prefixed with     : {image_name}_\n")
            answer = input("Continue? [Y/n]: ").strip().lower()
            if answer not in ("", "y", "yes"):
                vprint(3,"Aborted by user.")
                _cleanup.cleanup("Cleaning up after user abort")
                sys.exit(0)

        # --- Deploy files ---
        deploy_files(version_dir, image_path, image_name,
                     uuids=info.get("uuids", []))

    except (RuntimeError, FileNotFoundError) as e:
        vprint(1,f"Error: {e}", stream=sys.stderr)
        _cleanup.cleanup("Cleaning up after error")
        sys.exit(1)

    except Exception as e:
        vprint(1,f"Unexpected error: {e}", stream=sys.stderr)
        _cleanup.cleanup("Cleaning up after unexpected error")
        raise

    finally:
        _cleanup.cleanup("Final cleanup")

    vprint(2,"[done] Complete.")


if __name__ == "__main__":
    main()

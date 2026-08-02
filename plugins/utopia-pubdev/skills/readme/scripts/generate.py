#!/usr/bin/env python3
"""Generate + place Utopia brand-chip headers for every publishable package in a repo.

Discovers packages (pubspec.yaml, skipping examples / workspace roots / brick
templates / publish_to:none), renders each chip to docs/header.png, and writes a
manifest with the natural @1x width to embed in each README.

It does NOT edit READMEs - follow references/readme-structure.md for the <img> tag
(width = manifest width, no height/stretch) and the rest of the README.

Usage:
  npm i puppeteer-core          # once, in this scripts/ dir
  python3 generate.py --repo /path/to/repo [--repo /path/to/other] [--out manifest.json]
  python3 generate.py           # defaults --repo to the current directory
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chip

SKIP = ("/.dart_tool/", "/build/", "/example", "/.symlinks/", "/ios/", "/android/",
        "/macos/", "/windows/", "/linux/", "/web/", "/.git/", "/test/", "/.fvm/", "/bricks/")
HERE = os.path.dirname(os.path.abspath(__file__))


def field(txt, key):
    m = re.search(r'(?m)^%s:\s*(.*)$' % key, txt)
    return m.group(1).strip().strip('"\'') if m else ""


def discover(root):
    """Yield (package_name, package_dir) for each publishable package under root."""
    for dp, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        if any(s in dp + "/" for s in SKIP):
            continue
        if "pubspec.yaml" not in files:
            continue
        t = open(os.path.join(dp, "pubspec.yaml")).read()
        name, ver, pub = field(t, "name"), field(t, "version"), field(t, "publish_to")
        if not name or name.startswith("{{") or pub == "none" or not ver:
            continue  # skip templates, workspace roots (no version), publish_to:none
        yield name, dp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", action="append", default=None, help="repo root(s); default cwd")
    ap.add_argument("--out", default=None, help="manifest path (default <work>/manifest.json)")
    args = ap.parse_args()
    roots = [os.path.abspath(r) for r in (args.repo or [os.getcwd()])]

    pkgs = []
    for root in roots:
        for name, pkgdir in discover(root):
            pkgs.append((name, pkgdir))
    if not pkgs:
        print("No publishable packages found under:", ", ".join(roots)); return
    pkgs.sort()

    work = tempfile.mkdtemp(prefix="utopia-chips-")
    jobs = [dict(pkg=n, html=f"{work}/{n}.html", out=f"{work}/{n}.png") for n, _ in pkgs]
    for (n, _), j in zip(pkgs, jobs):
        open(j["html"], "w").write(chip.chip_html(n))
    json.dump(jobs, open(f"{work}/jobs.json", "w"))

    print(f"[render] {len(jobs)} chips via headless Chrome ...")
    r = subprocess.run(["node", os.path.join(HERE, "render.mjs"),
                        f"{work}/jobs.json", f"{work}/dims.json"],
                       capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-2000:]); sys.exit("render.mjs failed (puppeteer-core + Chrome installed?)")
    dims = json.load(open(f"{work}/dims.json"))

    manifest = []
    for name, pkgdir in pkgs:
        docs = os.path.join(pkgdir, "docs")
        os.makedirs(docs, exist_ok=True)
        target = os.path.join(docs, "header.png")
        shutil.copyfile(f"{work}/{name}.png", target)
        manifest.append(dict(pkg=name, wordmark=chip.main_word(name),
                             pkg_dir=pkgdir, readme=os.path.join(pkgdir, "README.md"),
                             target_png=target, rel_src="docs/header.png",
                             width=dims[name]["w"]))
    out = args.out or os.path.join(work, "manifest.json")
    json.dump(manifest, open(out, "w"), indent=2)

    print(f"\n[done] placed {len(manifest)} headers. manifest: {out}\n")
    print(f"{'package':<32}{'width':>6}  header")
    for m in manifest:
        print(f"{m['pkg']:<32}{m['width']:>6}  {os.path.relpath(m['target_png'])}")
    print("\nNext: add the <img> to each README per references/readme-structure.md "
          "(width = the value above, no height/stretch).")


if __name__ == "__main__":
    main()

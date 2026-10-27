#!/usr/bin/env python3
"""Static reference scan for a Godot 4.x project (no Godot needed).

Checks every .tscn/.tres, every .gd and project.godot for references that
don't resolve on disk:

  ERROR  ext_resource path that doesn't exist (or differs only in case:
         macOS is case-insensitive, exported .pck files are not)
  ERROR  ext_resource uid that belongs to a DIFFERENT file than its path
         (Godot trusts the uid and silently loads the other file)
  ERROR  ExtResource("id") / SubResource("id") with no matching declaration,
         or a duplicate id inside one file
  ERROR  the same uid declared by two files
  ERROR  preload/load("uid://...") or "res://..." in a .gd / project.godot
         that doesn't resolve
  WARN   ext_resource uid unknown to the project (Godot prints
         "invalid UID ... using text path instead" and falls back to path)
  WARN   metadata/_custom_type_script uid that is unknown or isn't the
         file's script
  WARN   [connection] method="..." that no func in any project .gd defines
  INFO   ext_resource without uid, load_steps that doesn't match
         ext + sub + 1 (only a progress hint; harmless)

Errors listed in baseline.txt (pre-existing, not yours to fix) are reported
as KNOWN and don't fail the run.

Usage: check_refs.py [--root DIR] [--strict] [--verbose] [--summary] [--no-baseline]
Exit status: 0 = no new errors (with --strict: and no warnings), 1 = errors,
2 = no project.godot found.
"""
import argparse
import os
import re
import sys
from collections import defaultdict

SKIP_DIRS = {".godot", ".git", ".import"}  # plus any hidden dir, which Godot ignores too

HEADER_RE = re.compile(r'^\[gd_(scene|resource)\b(.*)\]\s*$')
EXT_RE = re.compile(r'^\[ext_resource\b(.*)\]\s*$')
SUB_RE = re.compile(r'^\[sub_resource\b(.*)\]\s*$')
ATTR_RE = re.compile(r'(\w+)=("(?:[^"\\]|\\.)*"|\S+)')
REF_RE = re.compile(r'\b(ExtResource|SubResource)\("([^"]*)"\)')
CONNECTION_RE = re.compile(r'^\[connection\b(.*)\]\s*$')
FUNC_RE = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\(')
CUSTOM_TYPE_RE = re.compile(r'^metadata/_custom_type_script\s*=\s*"(uid://[a-z0-9]+)"')
SCRIPT_PROP_RE = re.compile(r'^script\s*=\s*ExtResource\("([^"]*)"\)')
UID_LITERAL_RE = re.compile(r'"(uid://[a-z0-9]+)"')
RES_LITERAL_RE = re.compile(r'"(res://[^"]+)"')
IMPORT_UID_RE = re.compile(r'^uid="(uid://[a-z0-9]+)"')


class Report:
    def __init__(self) -> None:
        self.items = []  # (level, file, line, msg)

    def add(self, level: str, file: str, line: int, msg: str) -> None:
        self.items.append((level, file, line, msg))

    def count(self, level: str) -> int:
        return sum(1 for i in self.items if i[0] == level)


def attrs(text: str) -> dict:
    out = {}
    for k, v in ATTR_RE.findall(text):
        out[k] = v[1:-1] if v.startswith('"') else v
    return out


def walk(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not d.startswith("."))
        for f in sorted(filenames):
            if not f.startswith("_tmp_"):  # temporary harness files (possibly another agent's)
                yield os.path.join(dirpath, f)


def to_res(root: str, path: str) -> str:
    return "res://" + os.path.relpath(path, root).replace(os.sep, "/")


def exists_exact_case(root: str, res_path: str):
    """Returns (exists, exact_case)."""
    rel = res_path[len("res://"):]
    full = os.path.join(root, rel)
    if not os.path.exists(full):
        return False, False
    cur = root
    for part in rel.split("/"):
        if part not in os.listdir(cur):
            return True, False
        cur = os.path.join(cur, part)
    return True, True


def build_uid_map(root: str, report: Report) -> dict:
    """uid -> res path, from .uid files, .import files and .tscn/.tres headers."""
    owners = defaultdict(set)
    for path in walk(root):
        name = os.path.basename(path)
        if name.endswith(".uid"):
            with open(path, encoding="utf-8", errors="replace") as fh:
                uid = fh.read().strip()
            if uid.startswith("uid://"):
                owners[uid].add(to_res(root, path[:-4]))
        elif name.endswith(".import"):
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    m = IMPORT_UID_RE.match(line)
                    if m:
                        owners[m.group(1)].add(to_res(root, path[:-7]))
                        break
        elif name.endswith((".tscn", ".tres")):
            with open(path, encoding="utf-8", errors="replace") as fh:
                m = HEADER_RE.match(fh.readline())
            if m:
                uid = attrs(m.group(2)).get("uid")
                if uid:
                    owners[uid].add(to_res(root, path))
    uid_map = {}
    for uid, paths in owners.items():
        if len(paths) > 1:
            report.add("ERROR", sorted(paths)[0], 1,
                       "uid %s is declared by several files: %s" % (uid, ", ".join(sorted(paths))))
        uid_map[uid] = sorted(paths)[0]
    return uid_map


def check_res_path(root: str, report: Report, file: str, line: int, res_path: str, what: str) -> None:
    res_path = res_path.split("::")[0]
    exists, exact = exists_exact_case(root, res_path)
    if not exists:
        report.add("ERROR", file, line, "%s points to missing file %s" % (what, res_path))
    elif not exact:
        report.add("ERROR", file, line, "%s %s differs from the file on disk only by case "
                   "(works on macOS, breaks in exports)" % (what, res_path))


def scan_text_resource(root: str, path: str, uid_map: dict, report: Report, funcs: set) -> None:
    file = to_res(root, path)
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    if not lines:
        report.add("ERROR", file, 1, "empty file")
        return
    header = HEADER_RE.match(lines[0])
    if not header:
        report.add("ERROR", file, 1, "first line is not a [gd_scene ...] / [gd_resource ...] header")
        return
    head = attrs(header.group(2))
    if head.get("format") != "3":
        report.add("WARN", file, 1, "format=%s (Godot 4 text files use format=3)" % head.get("format"))

    ext_ids = {}
    ext_paths = {}
    sub_ids = {}
    refs = []
    script_id = None
    for n, line in enumerate(lines, 1):
        m = EXT_RE.match(line)
        if m:
            a = attrs(m.group(1))
            rid, rpath, ruid = a.get("id"), a.get("path"), a.get("uid")
            if rid is None or rpath is None:
                report.add("ERROR", file, n, "ext_resource without id or path")
                continue
            if rid in ext_ids:
                report.add("ERROR", file, n, 'duplicate ext_resource id "%s" (first at line %d)' % (rid, ext_ids[rid]))
            ext_ids[rid] = n
            ext_paths[rid] = rpath
            check_res_path(root, report, file, n, rpath, "ext_resource")
            if ruid is None:
                report.add("INFO", file, n, "ext_resource %s has no uid (resolved by path only)" % rpath)
            elif ruid not in uid_map:
                report.add("WARN", file, n, "unknown uid %s for %s (Godot falls back to the path; "
                           "real uid is %s)" % (ruid, rpath, real_uid_of(uid_map, rpath)))
            elif uid_map[ruid] != rpath:
                report.add("ERROR", file, n, "uid %s belongs to %s but path says %s "
                           "(Godot loads the uid's file)" % (ruid, uid_map[ruid], rpath))
            continue
        m = CONNECTION_RE.match(line)
        if m:
            method = attrs(m.group(1)).get("method")
            if method and method not in funcs:
                report.add("WARN", file, n, 'connection method "%s" is not defined by any func in the '
                           "project's scripts (typo? built-in methods are fine)" % method)
            continue
        m = SUB_RE.match(line)
        if m:
            sid = attrs(m.group(1)).get("id")
            if sid in sub_ids:
                report.add("ERROR", file, n, 'duplicate sub_resource id "%s" (first at line %d)' % (sid, sub_ids[sid]))
            sub_ids[sid] = n
            script_id = None
            continue
        if line.startswith("["):
            # new [node]/[resource]/[sub_resource] section: its script/metadata start fresh
            script_id = None
        for kind, rid in REF_RE.findall(line):
            refs.append((n, kind, rid))
        m = SCRIPT_PROP_RE.match(line)
        if m:
            script_id = m.group(1)
        m = CUSTOM_TYPE_RE.match(line)
        if m:
            ctuid = m.group(1)
            if ctuid not in uid_map:
                report.add("WARN", file, n, "metadata/_custom_type_script uid %s is unknown "
                           "(script is %s, uid %s)" % (ctuid, ext_paths.get(script_id, "?"),
                                                      real_uid_of(uid_map, ext_paths.get(script_id, ""))))
            elif script_id in ext_paths and uid_map[ctuid] != ext_paths[script_id]:
                report.add("WARN", file, n, "metadata/_custom_type_script uid %s is %s, "
                           "but the script is %s" % (ctuid, uid_map[ctuid], ext_paths[script_id]))

    for n, kind, rid in refs:
        if kind == "ExtResource" and rid not in ext_ids:
            report.add("ERROR", file, n, 'ExtResource("%s") is not declared' % rid)
        elif kind == "SubResource" and rid not in sub_ids:
            report.add("ERROR", file, n, 'SubResource("%s") is not declared' % rid)
        elif kind == "SubResource" and n < sub_ids[rid]:
            report.add("ERROR", file, n, 'SubResource("%s") used before it is declared' % rid)

    steps = head.get("load_steps")
    expected = len(ext_ids) + len(sub_ids) + 1
    if steps is not None and steps.isdigit() and int(steps) != expected:
        report.add("INFO", file, 1, "load_steps=%s, expected %d (ext %d + sub %d + 1)"
                   % (steps, expected, len(ext_ids), len(sub_ids)))


def real_uid_of(uid_map: dict, res_path: str) -> str:
    for uid, p in uid_map.items():
        if p == res_path:
            return uid
    return "<none>"


def scan_literals(root: str, path: str, uid_map: dict, report: Report) -> None:
    file = to_res(root, path)
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            code = line.split("#", 1)[0] if path.endswith(".gd") else line
            if path.endswith("project.godot") and line.lstrip().startswith(";"):
                continue
            for uid in UID_LITERAL_RE.findall(code):
                if uid not in uid_map:
                    report.add("ERROR", file, n, "%s does not resolve to any file" % uid)
            for res in RES_LITERAL_RE.findall(code):
                if res.endswith("/") or "%" in res or "{" in res:
                    continue  # directory or format string
                check_res_path(root, report, file, n, res, "string")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", help="project root (dir with project.godot); default: search upward from cwd")
    ap.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    ap.add_argument("--verbose", action="store_true", help="also print INFO lines")
    ap.add_argument("--summary", action="store_true", help="print ERRORs, but only counts for WARN/INFO")
    ap.add_argument("--baseline", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "baseline.txt"),
                    help="known pre-existing errors that don't fail the run (default: baseline.txt next to "
                         "this script); one 'res://file: message' per line, # comments")
    ap.add_argument("--no-baseline", action="store_true", help="treat baseline errors as errors")
    args = ap.parse_args()

    root = args.root
    if root is None:
        root = os.getcwd()
        while not os.path.exists(os.path.join(root, "project.godot")):
            parent = os.path.dirname(root)
            if parent == root:
                print("check_refs: no project.godot found above cwd", file=sys.stderr)
                return 2
            root = parent
    root = os.path.abspath(root)

    report = Report()
    uid_map = build_uid_map(root, report)
    funcs = set()
    for path in walk(root):
        if path.endswith(".gd"):
            with open(path, encoding="utf-8", errors="replace") as fh:
                funcs.update(m.group(1) for m in map(FUNC_RE.match, fh) if m)
    n_files = 0
    for path in walk(root):
        if path.endswith((".tscn", ".tres")):
            n_files += 1
            scan_text_resource(root, path, uid_map, report, funcs)
        elif path.endswith(".gd"):
            n_files += 1
            scan_literals(root, path, uid_map, report)
    scan_literals(root, os.path.join(root, "project.godot"), uid_map, report)

    known = set()
    if not args.no_baseline and os.path.exists(args.baseline):
        with open(args.baseline, encoding="utf-8") as fh:
            known = {l.strip() for l in fh if l.strip() and not l.lstrip().startswith("#")}
    seen = set()
    for i, (level, file, line, msg) in enumerate(report.items):
        key = "%s: %s" % (file, msg)
        if level == "ERROR" and key in known:
            report.items[i] = ("KNOWN", file, line, msg)
            seen.add(key)
    for key in sorted(known - seen):
        report.add("INFO", "baseline", 0, "no longer occurs, remove it from the baseline: " + key)

    items = sorted(report.items, key=lambda i: (i[0] != "ERROR", i[0], i[1], i[2]))
    if args.verbose:
        for level, file, line, msg in items:
            print("%-5s %s:%d: %s" % (level, file, line, msg))
    else:
        for level, file, line, msg in items:
            if level == "ERROR":
                print("ERROR %s:%d: %s" % (file, line, msg))
            elif level == "KNOWN" and not args.summary:
                print("KNOWN %s:%d: %s (in baseline)" % (file, line, msg))
        if not args.summary:
            # The same broken uid is usually copy-pasted into many files: print it once.
            groups = defaultdict(list)
            for level, file, line, msg in items:
                if level == "WARN":
                    groups[msg].append("%s:%d" % (file.replace("res://", ""), line))
            for msg, where in sorted(groups.items(), key=lambda g: -len(g[1])):
                more = " +%d more" % (len(where) - 3) if len(where) > 3 else ""
                print("WARN  %dx %s\n        in %s%s" % (len(where), msg, ", ".join(where[:3]), more))

    errors, warns, infos = report.count("ERROR"), report.count("WARN"), report.count("INFO")
    print("check_refs: %d files, %d uids known: %d error(s), %d known (baseline), %d warning(s), %d info%s"
          % (n_files + 1, len(uid_map), errors, report.count("KNOWN"), warns, infos,
             "" if args.verbose else " (--verbose lists every line)"))
    if errors or (args.strict and warns):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

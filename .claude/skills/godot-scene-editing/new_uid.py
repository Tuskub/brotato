#!/usr/bin/env python3
"""Print fresh Godot 4 resource UIDs (uid://...) that are not used anywhere in the project.

Same encoding as Godot's ResourceUID::id_to_text(): a random non-negative 63-bit id
written in base 34 with the digits a..y then 0..8 (no 'z', no '9'), 12-13 characters.

Usage: new_uid.py [COUNT]            print COUNT uids (default 1)
       new_uid.py --file foo.gd      also write foo.gd.uid (refuses to overwrite)
"""
import os
import re
import secrets
import sys

DIGITS = "abcdefghijklmnopqrstuvwxy012345678"  # 25 letters + 9 digits = base 34


def id_to_text(i: int) -> str:
    s = ""
    while True:
        s = DIGITS[i % 34] + s
        i //= 34
        if i == 0:
            return "uid://" + s


def used_uids(root: str) -> set:
    found = set()
    pat = re.compile(r"uid://[a-z0-9]+")
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for f in filenames:
            if f.endswith((".tscn", ".tres", ".uid", ".import", ".gd", ".godot", ".cfg")):
                try:
                    with open(os.path.join(dirpath, f), encoding="utf-8", errors="replace") as fh:
                        found.update(pat.findall(fh.read()))
                except OSError:
                    pass
    return found


def project_root() -> str:
    d = os.getcwd()
    while not os.path.exists(os.path.join(d, "project.godot")):
        parent = os.path.dirname(d)
        if parent == d:
            sys.exit("new_uid: run inside the Godot project (no project.godot found)")
        d = parent
    return d


def main() -> None:
    args = sys.argv[1:]
    target = None
    if args[:1] == ["--file"]:
        if len(args) != 2:
            sys.exit(__doc__)
        target = args[1] + ".uid"
        if os.path.exists(target):
            sys.exit("new_uid: %s already exists (%s)" % (target, open(target).read().strip()))
        count = 1
    else:
        count = int(args[0]) if args else 1
    used = used_uids(project_root())
    out = []
    while len(out) < count:
        uid = id_to_text(secrets.randbits(63))
        if uid not in used and uid not in out:
            out.append(uid)
    if target:
        with open(target, "w") as fh:
            fh.write(out[0] + "\n")
        print("%s -> %s" % (out[0], target))
    else:
        print("\n".join(out))


if __name__ == "__main__":
    main()

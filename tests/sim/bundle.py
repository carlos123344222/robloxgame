#!/usr/bin/env python3
"""Bundles src/shared/**/*.luau into tests/sim/bundle_data.luau so the headless simulation can load
the real movement modules with a fake instance tree (the plain Luau CLI has no filesystem access)."""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SHARED = ROOT / "src" / "shared"
SERVER_NPC = ROOT / "src" / "server" / "NPC"
NPC_MODULES = ["NPCAnimator", "NPCBrain", "NPCConfig", "Navigator", "PathScheduler"]
OUT = pathlib.Path(__file__).resolve().parent / "bundle_data.luau"

entries = []
for path in sorted(SHARED.rglob("*.luau")):
    relative = path.relative_to(SHARED).with_suffix("")
    key = "Shared/" + "/".join(relative.parts)
    source = path.read_text()
    assert "]==]" not in source, f"{path} contains a long-string terminator"
    entries.append(f'\t["{key}"] = [==[\n{source}\n]==],')

for name in NPC_MODULES:
    source = (SERVER_NPC / f"{name}.luau").read_text()
    assert "]==]" not in source
    entries.append(f'\t["Server/NPC/{name}"] = [==[\n{source}\n]==],')

OUT.write_text("return {\n" + "\n".join(entries) + "\n}\n")
print(f"bundled {len(entries)} modules -> {OUT}")

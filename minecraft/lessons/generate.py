#!/usr/bin/env python3
"""Build a Minecraft Java datapack from a lesson file.

A lesson is a JSON file with a list of steps. Each step shows a short message
in chat with clickable answer buttons. Clicking a button runs /trigger, which
works for players without op. Right answers advance the lesson and can run
build commands at the lesson anchor; wrong answers show a hint and re-ask.

Targets Minecraft Java 1.21.5+ (SNBT text components, click_event syntax).

Usage:
    python3 generate.py lessons/paragraph-burger.json -o build/
"""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

PACK_FORMAT_MIN = 71  # 1.21.5
PACK_FORMAT_MAX = 999

DEFAULT_PRAISE = [
    "Nice job!",
    "You got it!",
    "Awesome!",
    "That's right!",
    "Great thinking!",
]


def text(s, **style):
    """One text component as a dict."""
    c = {"text": s}
    c.update(style)
    return c


def button(label, value, trigger, hover):
    return text(
        f"[{label}]",
        color="green",
        bold=True,
        click_event={"action": "run_command", "command": f"/trigger {trigger} set {value}"},
        hover_event={"action": "show_text", "value": hover},
    )


def tellraw(target, components):
    # JSON is valid SNBT for text components, as long as we keep it on one line.
    return "tellraw " + target + " " + json.dumps([text("")] + components, ensure_ascii=False)


class Lesson:
    def __init__(self, data):
        self.d = data
        self.ns = data["namespace"]
        if not re.fullmatch(r"[a-z0-9_]+", self.ns):
            sys.exit(f"namespace must be [a-z0-9_]: {self.ns}")
        self.trig = f"{self.ns}_ans"
        self.stage = f"{self.ns}_stage"
        self.key = f"{self.ns}_key"
        self.tmp = f"{self.ns}_tmp"
        self.anchor = f"@e[type=marker,tag={self.ns}_anchor,limit=1]"
        self.speaker = data.get("speaker", "Teacher")
        self.files = {}

    def fn(self, path, lines):
        self.files[path] = lines

    def say(self, line):
        return tellraw("@s", [text(f"[{self.speaker}] ", color="gold"), text(line, color="white")])

    def at_anchor(self, cmd):
        return f"execute at {self.anchor} rotated as {self.anchor} run {cmd}"

    def build(self):
        ns, steps, title = self.ns, self.d["steps"], self.d["title"]
        n = len(steps)

        self.fn("load", [
            f"scoreboard objectives add {self.trig} trigger",
            f"scoreboard objectives add {self.stage} dummy",
            f"scoreboard objectives add {self.key} dummy",
            f"scoreboard objectives add {self.tmp} dummy",
            f"scoreboard players set #10 {self.tmp} 10",
            tellraw("@a[gamemode=creative]", [text(f"Lesson loaded: {title}. Start it with /execute as <player> at @s run function {ns}:start", color="gray")]),
        ])

        self.fn("tick", [
            f"scoreboard players enable @a {self.trig}",
            f"execute as @a[scores={{{self.trig}=1..}}] run function {ns}:answer",
        ])

        # Snap the anchor to the nearest cardinal direction so builds come out square.
        self.fn("start", [
            f"kill @e[type=marker,tag={ns}_anchor]",
            f"summon marker ~ ~ ~ {{Tags:[\"{ns}_anchor\"]}}",
            f"execute store result score #yaw {self.tmp} run data get entity @s Rotation[0]",
            f"scoreboard players add #yaw {self.tmp} 405",
            f"scoreboard players set #360 {self.tmp} 360",
            f"scoreboard players set #90 {self.tmp} 90",
            f"scoreboard players operation #yaw {self.tmp} %= #360 {self.tmp}",
            f"scoreboard players operation #yaw {self.tmp} /= #90 {self.tmp}",
            f"scoreboard players operation #yaw {self.tmp} *= #90 {self.tmp}",
            f"execute store result entity {self.anchor} Rotation[0] float 1 run scoreboard players get #yaw {self.tmp}",
            *[self.at_anchor(c) for c in self.d.get("setup_build", [])],
            *self.d.get("setup_commands", []),
            f"scoreboard players set @s {self.stage} 1",
            f"function {ns}:ask",
        ])

        self.fn("reset", [
            f"kill @e[type=marker,tag={ns}_anchor]",
            *self.d.get("reset_commands", []),
            f"scoreboard players reset @s {self.stage}",
        ])

        # Button values are stage*10 + option, so a click on an old question's
        # button can never be mistaken for an answer to the current one.
        self.fn("answer", [
            f"scoreboard players operation @s {self.tmp} = @s {self.trig}",
            f"scoreboard players operation @s {self.tmp} /= #10 {self.tmp}",
            f"execute unless score @s {self.tmp} = @s {self.stage} run function {ns}:stale",
            f"execute if score @s {self.tmp} = @s {self.stage} if score @s {self.trig} = @s {self.key} run function {ns}:correct",
            f"execute if score @s {self.tmp} = @s {self.stage} unless score @s {self.trig} = @s {self.key} run function {ns}:wrong",
            f"scoreboard players set @s {self.trig} 0",
        ])

        self.fn("stale", [
            tellraw("@s", [text("That button is from an earlier question. Use the newest one!", color="gray", italic=True)]),
        ])

        self.fn("ask", [
            f"execute if score @s {self.stage} matches {i} run function {ns}:step/{i}/ask"
            for i in range(1, n + 1)
        ] + [f"execute if score @s {self.stage} matches {n + 1} run function {ns}:finish"])

        self.fn("correct", [
            f"execute if score @s {self.stage} matches {i} run function {ns}:step/{i}/correct"
            for i in range(1, n + 1)
        ] + [f"scoreboard players add @s {self.stage} 1", f"function {ns}:ask"])

        self.fn("wrong", [
            f"execute if score @s {self.stage} matches {i} run function {ns}:step/{i}/wrong"
            for i in range(1, n + 1)
        ])

        for i, step in enumerate(steps, start=1):
            self.build_step(i, step)

        fin = self.d.get("finish", {})
        self.fn("finish", [
            *[self.say(line) for line in fin.get("say", [])],
            *fin.get("commands", []),
            *[self.at_anchor(c) for c in fin.get("build", [])],
            f"scoreboard players set @s {self.stage} {n + 2}",
        ])

    def build_step(self, i, step):
        ns = self.ns
        options = step.get("options", ["Next"])
        answer = step.get("answer", 1)
        if not 1 <= answer <= len(options) <= 9:
            sys.exit(f"step {i}: answer {answer} out of range for {len(options)} options")
        layout = step.get("layout", "inline" if all(len(o) <= 20 for o in options) else "lines")

        ask = ["tellraw @s \"\""]
        if step.get("title"):
            ask.append(f'title @s title {json.dumps(text(step["title"], color="gold"))}')
            ask.append(f"playsound minecraft:ui.toast.challenge_complete master @s ~ ~ ~ 0.6")
        for line in step.get("say", []):
            ask.append(self.say(line))
        if step.get("sentence"):
            ask.append(tellraw("@s", [text('  "', color="aqua"), text(step["sentence"], color="aqua", bold=True), text('"', color="aqua")]))
        if step.get("prompt"):
            ask.append(tellraw("@s", [text(step["prompt"], color="yellow")]))

        hover = step.get("hover", "Click to choose")
        if layout == "inline":
            comps = [text("  ")]
            for o, label in enumerate(options, start=1):
                comps += [button(label, i * 10 + o, self.trig, hover), text("  ")]
            ask.append(tellraw("@s", comps))
        else:
            for o, label in enumerate(options, start=1):
                ask.append(tellraw("@s", [text("  "), button(str(o), i * 10 + o, self.trig, hover), text(f" {label}", color="white")]))
        ask.append(f"scoreboard players set @s {self.key} {i * 10 + answer}")
        self.fn(f"step/{i}/ask", ask)

        correct = []
        if len(options) > 1:
            praise = step.get("praise") or DEFAULT_PRAISE[i % len(DEFAULT_PRAISE)]
            correct += [
                self.say(praise),
                "playsound minecraft:entity.player.levelup master @s ~ ~ ~ 0.7 1.4",
                "particle minecraft:happy_villager ~ ~1 ~ 0.6 0.6 0.6 0 20",
            ]
        correct += [self.at_anchor(c) for c in step.get("build", [])]
        correct += step.get("commands", [])
        self.fn(f"step/{i}/correct", correct)

        hint = step.get("hint", "Not quite. Read it again and try once more!")
        self.fn(f"step/{i}/wrong", [
            "playsound minecraft:entity.villager.no master @s ~ ~ ~ 0.8",
            tellraw("@s", [text("[Hint] ", color="light_purple"), text(hint, color="white")]),
            f"function {ns}:step/{i}/ask",
        ])

    def validate(self):
        """Cheap checks we can do without a Minecraft server."""
        ok = True
        for path, lines in self.files.items():
            for ln in lines:
                if "\n" in ln or ln.startswith("/"):
                    print(f"{path}: bad line {ln!r}", file=sys.stderr)
                    ok = False
                for ref in re.findall(rf"function ({self.ns}:[a-z0-9_/]+)", ln):
                    if ref.split(":", 1)[1] not in self.files:
                        print(f"{path}: missing function {ref}", file=sys.stderr)
                        ok = False
                if ln.startswith("tellraw") or " title " in ln:
                    payload = ln.split(" ", 2)[2] if ln.startswith("tellraw") else ln.split(" title ", 1)[1]
                    try:
                        json.loads(payload)
                    except json.JSONDecodeError as e:
                        print(f"{path}: bad text component ({e}): {ln}", file=sys.stderr)
                        ok = False
                if "\u2014" in ln:
                    print(f"{path}: em dash in text", file=sys.stderr)
                    ok = False
        return ok

    def write(self, out):
        root = Path(out) / self.ns
        if root.exists():
            shutil.rmtree(root)
        fdir = root / "data" / self.ns / "function"
        for path, lines in self.files.items():
            p = fdir / f"{path}.mcfunction"
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        tags = root / "data" / "minecraft" / "tags" / "function"
        tags.mkdir(parents=True)
        (tags / "load.json").write_text(json.dumps({"values": [f"{self.ns}:load"]}, indent=2) + "\n")
        (tags / "tick.json").write_text(json.dumps({"values": [f"{self.ns}:tick"]}, indent=2) + "\n")
        (root / "pack.mcmeta").write_text(json.dumps({"pack": {
            "description": self.d["title"],
            "pack_format": PACK_FORMAT_MIN,
            "supported_formats": [PACK_FORMAT_MIN, PACK_FORMAT_MAX],
            "min_format": PACK_FORMAT_MIN,
            "max_format": PACK_FORMAT_MAX,
        }}, indent=2) + "\n")
        archive = shutil.make_archive(str(root), "zip", root)
        return root, archive


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("lesson", help="lesson JSON file")
    ap.add_argument("-o", "--out", default="build", help="output directory (default: build)")
    args = ap.parse_args()

    lesson = Lesson(json.loads(Path(args.lesson).read_text(encoding="utf-8")))
    lesson.build()
    if not lesson.validate():
        sys.exit(1)
    root, archive = lesson.write(args.out)
    print(f"{len(lesson.files)} functions -> {root}")
    print(f"zip -> {archive}")


if __name__ == "__main__":
    main()

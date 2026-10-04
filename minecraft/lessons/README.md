# Minecraft Lessons

Homework practice as Minecraft Java datapacks. Each lesson is a JSON file in
`lessons/`, and `generate.py` turns it into a datapack. Players answer by clicking
buttons in chat (uses `/trigger`, so no op needed). Right answers advance the lesson
and can build things in the world; wrong answers show a hint and ask again.

Requires Minecraft Java **1.21.5 or newer**.

## Build

```bash
python3 generate.py lessons/paragraph-burger.json -o build
```

Output: `build/<namespace>/` (datapack folder) and `build/<namespace>.zip`.

## Play

Use a **separate lesson world** (creative superflat works best). Starting a lesson
clears a 13x15 area in front of the player, so don't start one next to builds you care
about.

1. Copy the zip into `<world>/datapacks/` (singleplayer: `saves/<world>/datapacks/`).
2. Run `/reload` (or restart the server).
3. Stand where the lesson should go, face the open area, then a grown-up (op) runs:
   `/execute as <player> at @s run function pb:start`
4. The player clicks answers in chat.

Restart from the beginning with `function pb:start` again. `function pb:reset`
removes the lesson's NPC and labels (not the blocks).

## Lessons

| File | Namespace | Skill |
|------|-----------|-------|
| `paragraph-burger.json` | `pb` | 3rd grade paragraph writing: topic/detail/closing sentences, staying on topic, sequence words, then writing a paragraph in a Book & Quill |

## Lesson format

```json
{
  "namespace": "pb",
  "title": "Paragraph Burger",
  "speaker": "Chef Patty",
  "setup_build": ["fill ^-3 ^ ^4 ^3 ^ ^10 white_concrete"],
  "steps": [
    {"say": ["Intro line"], "options": ["Next"]},
    {
      "sentence": "A wolf pack works together to hunt.",
      "prompt": "Which part of the burger is this?",
      "options": ["Top bun", "Filling", "Bottom bun"],
      "answer": 2,
      "hint": "Shown on a wrong answer",
      "praise": "Shown on a right answer",
      "build": ["commands run at the lesson anchor, ^ coords face forward"],
      "commands": ["commands run as the player"]
    }
  ],
  "finish": {"say": [], "commands": [], "build": []}
}
```

- `build` and `setup_build` run at a marker placed where the lesson started, snapped to
  the nearest compass direction, so `^left ^up ^forward` coordinates come out square.
- Options of 20 characters or less show as inline buttons; longer ones show one per line.
- Up to 9 options per step.

## Privacy

Lessons here must be generic: no names, schools, teachers or photos of real homework.
Homework itself stays out of this repo.

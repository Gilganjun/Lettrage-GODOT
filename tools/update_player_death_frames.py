import re
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "resources/sprite_frames/player_frames.tres"
content = path.read_text(encoding="utf-8")

content = re.sub(
    r'\[ext_resource type="Texture2D" path="res://characters/Character_Death\d\.png" id="3[456]"\]\n',
    "",
    content,
)

death_lines = []
for i in range(1, 31):
    num = f"{i:03d}"
    rid = 33 + i if i <= 3 else 60 + i
    death_lines.append(
        f'[ext_resource type="Texture2D" path="res://assets/Characters/Original_Char/Death/death_{num}.png" id="{rid}"]'
    )
death_block = "\n".join(death_lines) + "\n"
content = content.replace("[resource]", death_block + "[resource]", 1)

frame_parts = []
for i in range(1, 31):
    rid = 33 + i if i <= 3 else 60 + i
    frame_parts.append(
        '{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % rid
    )
frames_str = ", ".join(frame_parts)

pattern = (
    r'\}, \{\n"frames": \[\{\n"duration": 1\.0,\n"texture": ExtResource\("34"\).*?'
    r'"name": &"Death",\n"speed": [\d.]+'
)
match = re.search(pattern, content, re.DOTALL)
if not match:
    raise SystemExit("Could not find Death animation block")

new_death = '''}, {
"frames": [%s],
"loop": false,
"name": &"Death",
"speed": 12.0''' % frames_str
content = content[: match.start()] + new_death + content[match.end() :]
content = re.sub(r"load_steps=\d+", "load_steps=91", content, count=1)
path.write_text(content, encoding="utf-8", newline="\n")
print("Updated player_frames.tres Death animation with 30 frames")

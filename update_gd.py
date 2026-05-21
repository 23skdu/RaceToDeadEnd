import os
moves = {}
for root, _, files in os.walk("scripts"):
    for f in files:
        if f.endswith(".gd"):
            new_path = os.path.join(root, f).replace("\\", "/")
            old_path = new_path.replace("scripts/", "", 1)
            moves[old_path] = new_path

for root, _, files in os.walk("scripts"):
    for f in files:
        if f.endswith(".gd"):
            gd_path = os.path.join(root, f)
            with open(gd_path, 'r', encoding='utf-8') as file:
                content = file.read()
            modified = False
            for old, new in moves.items():
                old_res = "res://" + old
                new_res = "res://" + new
                if old_res in content:
                    content = content.replace(old_res, new_res)
                    modified = True
            if modified:
                with open(gd_path, 'w', encoding='utf-8') as file:
                    file.write(content)
                print(f"Updated {gd_path}")

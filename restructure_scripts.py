import os
import shutil
import glob

def restructure():
    # Find all .gd files excluding addons/ and venv/
    gd_files = []
    for root, _, files in os.walk("."):
        if "addons" in root or "venv" in root or ".git" in root or "scripts" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                gd_files.append(os.path.join(root, f))
                
    # Create matching directories in scripts/ and move files
    moves = {}
    for old_path in gd_files:
        # e.g., ./scenes/player/Interceptor.gd -> scripts/scenes/player/Interceptor.gd
        new_path = os.path.normpath(old_path).replace("\\", "/")
        new_path = os.path.join("scripts", new_path)
        
        os.makedirs(os.path.dirname(new_path), exist_ok=True)
        shutil.move(old_path, new_path)
        moves[os.path.normpath(old_path).replace("\\", "/")] = new_path
        
    print(f"Moved {len(moves)} scripts to scripts/")

    # Update .tscn files
    tscn_files = []
    for root, _, files in os.walk("."):
        if "addons" in root or "venv" in root or ".git" in root:
            continue
        for f in files:
            if f.endswith(".tscn"):
                tscn_files.append(os.path.join(root, f))
                
    for tscn in tscn_files:
        with open(tscn, 'r', encoding='utf-8') as f:
            content = f.read()
            
        modified = False
        for old, new in moves.items():
            # In godot paths are res://scenes/...
            old_res = "res://" + old
            new_res = "res://" + new
            if old_res in content:
                content = content.replace(old_res, new_res)
                modified = True
                
        if modified:
            with open(tscn, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {tscn}")

    # Update project.godot (for autoloads and main scene if needed)
    with open("project.godot", 'r', encoding='utf-8') as f:
        content = f.read()
        
    modified = False
    for old, new in moves.items():
        old_res = "res://" + old
        new_res = "res://" + new
        if old_res in content:
            content = content.replace(old_res, new_res)
            modified = True
            
    if modified:
        with open("project.godot", 'w', encoding='utf-8') as f:
            f.write(content)
        print("Updated project.godot")

if __name__ == "__main__":
    restructure()

from PIL import Image
import os

def make_transparent(filename):
    if not os.path.exists(filename):
        print(f"Not found: {filename}")
        return
    img = Image.open(filename).convert("RGBA")
    data = img.getdata()
    bg_color = data[0]
    
    new_data = []
    for item in data:
        # Check if color is close to background color
        if abs(item[0] - bg_color[0]) < 10 and abs(item[1] - bg_color[1]) < 10 and abs(item[2] - bg_color[2]) < 10:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(filename, "PNG")
    print(f"Processed {filename}")

files = [
    "assets/sprites/enemies/drone.png",
    "assets/sprites/enemies/rotor.png",
    "assets/sprites/enemies/scav.png"
]

for f in files:
    make_transparent(f)

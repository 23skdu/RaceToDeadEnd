from PIL import Image
import sys

def check(filename):
    img = Image.open(filename).convert("RGBA")
    data = list(img.getdata())
    w, h = img.size
    corners = [data[0], data[w-1], data[-w], data[-1]]
    print(f"{filename} corners: {corners}")
    
    non_trans = sum(1 for p in data if p[3] > 0)
    print(f"Non-transparent: {non_trans}/{len(data)}")

check("assets/sprites/enemies/drone.png")
check("assets/sprites/enemies/rotor.png")
check("assets/sprites/enemies/scav.png")

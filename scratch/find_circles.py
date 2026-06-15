import os
from PIL import Image

def find_circles():
    img_path = '/home/oem/.gemini/antigravity/brain/3658ff69-8f22-4476-92f6-cfe5fab9eee1/media__1781510837765.png'
    img = Image.open(img_path).convert('RGB')
    width, height = img.size
    
    # Let's crop into a 2x3 grid to start with, then see where the circle boundary is
    # Columns: 3, Rows: 2
    col_width = width // 3
    row_height = height // 2
    
    os.makedirs('/home/oem/Desktop/Jaimakali/assets/avatars', exist_ok=True)
    
    # Let's do a test crop with some padding to ensure we capture the circles perfectly
    # Each circle is centered in its cell.
    # Cell 0,0: x from 0 to col_width, y from 0 to row_height
    # Cell 0,1: x from col_width to 2*col_width, y from 0 to row_height
    # etc.
    # Inside each cell, the avatar circle is centered.
    # Let's write a script to crop a square of size ~300x300 centered in each cell.
    
    for row in range(2):
        for col in range(3):
            cell_x_center = col * col_width + col_width // 2
            cell_y_center = row * row_height + row_height // 2
            
            # Since the circle radius is around 140 (diameter 280-300), let's crop a square of 320x320
            radius = 160
            left = max(0, cell_x_center - radius)
            top = max(0, cell_y_center - radius)
            right = min(width, cell_x_center + radius)
            bottom = min(height, cell_y_center + radius)
            
            # Crop and save
            cropped = img.crop((left, top, right, bottom))
            # Resize to 256x256 for standard avatar size
            cropped = cropped.resize((256, 256), Image.Resampling.LANCZOS)
            out_path = f'/home/oem/Desktop/Jaimakali/assets/avatars/male_{row*3 + col + 1}.png'
            cropped.save(out_path)
            print(f"Saved {out_path} with box {(left, top, right, bottom)}")

if __name__ == '__main__':
    find_circles()

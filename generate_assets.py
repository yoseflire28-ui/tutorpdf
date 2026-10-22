import os
from PIL import Image, ImageDraw

def main():
    # Ensure assets directory exists
    os.makedirs("assets/images", exist_ok=True)

    # 1. Generate App Icon (1024x1024)
    # Royal Blue background: #4169E1 (65, 105, 225)
    app_icon = Image.new("RGBA", (1024, 1024), (65, 105, 225, 255))
    draw = ImageDraw.Draw(app_icon)
    
    # Draw geometric design (elegant book or diamond outline)
    center = 512
    size = 250
    points = [
        (center, center - size),
        (center + size, center),
        (center, center + size),
        (center - size, center)
    ]
    draw.polygon(points, outline=(255, 255, 255, 255), width=24)
    
    # Draw smaller inner diamond
    inner_size = 120
    inner_points = [
        (center, center - inner_size),
        (center + inner_size, center),
        (center, center + inner_size),
        (center - inner_size, center)
    ]
    draw.polygon(inner_points, outline=(255, 255, 255, 255), width=12)

    app_icon.save("assets/images/app_icon.png", "PNG")
    print("Created assets/images/app_icon.png successfully.")

    # 2. Generate Splash Logo (512x512)
    # Transparent background, matching central white shape
    splash_logo = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw_splash = ImageDraw.Draw(splash_logo)
    
    # Draw a clean central white book/diamond outline matching the app icon style
    s_center = 256
    s_size = 120
    s_points = [
        (s_center, s_center - s_size),
        (s_center + s_size, s_center),
        (s_center, s_center + s_size),
        (s_center - s_size, s_center)
    ]
    draw_splash.polygon(s_points, outline=(255, 255, 255, 255), width=16)
    
    s_inner_size = 60
    s_inner_points = [
        (s_center, s_center - s_inner_size),
        (s_center + s_inner_size, s_center),
        (s_center, s_center + s_inner_size),
        (s_center - s_inner_size, s_center)
    ]
    draw_splash.polygon(s_inner_points, outline=(255, 255, 255, 255), width=8)

    splash_logo.save("assets/images/splash_logo.png", "PNG")
    print("Created assets/images/splash_logo.png successfully.")

if __name__ == "__main__":
    main()

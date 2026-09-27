import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_mellow_logo(size=1024):
    render_size = size * 2
    pad = int(render_size * 0.05)
    box = [pad, pad, render_size - pad, render_size - pad]
    radius = int(render_size * 0.22)

    # 1. 生成高保真 Squircle 遮罩
    mask = Image.new("L", (render_size, render_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(box, radius=radius, fill=255)

    # 2. 生成现代曜石深灰到声学夜间渐变底图
    bg_gradient = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_gradient)
    for y in range(render_size):
        ratio = y / render_size
        # 渐变从 #1C1F2B (28, 31, 43) 到 #0C0D13 (12, 13, 19)
        r = int(28 * (1 - ratio) + 12 * ratio)
        g = int(31 * (1 - ratio) + 13 * ratio)
        b = int(45 * (1 - ratio) + 20 * ratio)
        bg_draw.line([(0, y), (render_size, y)], fill=(r, g, b, 255))

    container = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    container.paste(bg_gradient, (0, 0), mask=mask)

    # 3. 边框微弱柔光 (1.5px @ 1024)
    border_draw = ImageDraw.Draw(container)
    border_draw.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 38), width=int(render_size * 0.005))

    # 4. 内部声学弥散光晕 (Acoustic Ambient Glow)
    glow = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = render_size // 2, render_size // 2
    glow_r = int(render_size * 0.36)
    
    # 核心紫罗兰弥散
    glow_draw.ellipse([cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r], fill=(139, 92, 246, 85))
    # 偏右暖金弥散
    glow_draw.ellipse([cx - int(glow_r * 0.4), cy - int(glow_r * 0.4), cx + int(glow_r * 0.9), cy + int(glow_r * 0.8)], fill=(245, 158, 11, 55))
    glow = glow.filter(ImageFilter.GaussianBlur(int(render_size * 0.09)))
    container.paste(Image.alpha_composite(Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0)), glow), (0, 0), mask=mask)

    # 5. 核心声学律动主体：5 根声学能量柱 + 流动旋律金光缎带
    icon_layer = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    icon_draw = ImageDraw.Draw(icon_layer)

    bars_config = [
        (-0.25, 0.24, (139, 92, 246)),   # 柔和紫罗兰
        (-0.125, 0.44, (168, 85, 247)),  # 亮紫
        (0.0,    0.60, (236, 72, 153)),  # 活力珊瑚粉
        (0.125,  0.46, (249, 115, 22)),  # 暖橙
        (0.25,   0.28, (245, 158, 11)),  # 琥珀暖金
    ]

    bar_width = int(render_size * 0.068)
    for rel_x, rel_h, color in bars_config:
        bx = int(cx + rel_x * render_size)
        bh = int(rel_h * render_size)
        by1 = cy - bh // 2
        by2 = cy + bh // 2
        rect = [bx - bar_width // 2, by1, bx + bar_width // 2, by2]
        r, g, b = color
        icon_draw.rounded_rectangle(rect, radius=bar_width // 2, fill=(r, g, b, 255))

    # 绘制高雅流畅的音律微光光带 (Melodic Wave Ribbon)
    ribbon_points = []
    steps = 100
    for s in range(steps + 1):
        t = s / steps
        rx = cx - int(render_size * 0.32) + int(render_size * 0.64 * t)
        ry = cy - int(math.sin(t * math.pi * 1.5) * render_size * 0.16) + int((t - 0.5) * render_size * 0.10)
        ribbon_points.append((rx, ry))

    for i in range(len(ribbon_points) - 1):
        p1 = ribbon_points[i]
        p2 = ribbon_points[i+1]
        t = i / len(ribbon_points)
        r = 255
        g = int(245 * (1 - t) + 215 * t)
        b = int(255 * (1 - t) + 160 * t)
        icon_draw.line([p1, p2], fill=(r, g, b, 240), width=int(render_size * 0.026))

    # 高斯模糊做微光发光层
    icon_glow = icon_layer.filter(ImageFilter.GaussianBlur(int(render_size * 0.025)))
    composite = Image.alpha_composite(container, icon_glow)
    composite = Image.alpha_composite(composite, icon_layer)

    # 高保真抗锯齿下采样
    final_img = composite.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

def create_mac_tray_icon():
    # 生成 22x22 和 44x44 (@2x) 单色透明状态栏图标
    sizes = [(22, 1), (44, 2)]
    icons = {}
    for sz, scale in sizes:
        img = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        cx, cy = sz // 2, sz // 2
        # 4 根极简声学音符微柱
        bars = [
            (-6 * scale, 6 * scale),
            (-2 * scale, 10 * scale),
            (2 * scale, 14 * scale),
            (6 * scale, 8 * scale),
        ]
        w = max(2, 2 * scale)
        for dx, h in bars:
            bx = cx + dx
            draw.rounded_rectangle([bx - w // 2, cy - h // 2, bx + w // 2, cy + h // 2], radius=1 * scale, fill=(255, 255, 255, 255))
        icons[sz] = img
    return icons

def distribute_icons(base_dir):
    print(">>> 正在生成 1024x1024 品牌 Logo 母版...")
    logo_1024 = create_mellow_logo(1024)

    # 1. 根目录及静态资源
    public_dir = os.path.join(base_dir, "public")
    os.makedirs(public_dir, exist_ok=True)
    logo_1024.save(os.path.join(public_dir, "logo.png"))
    logo_1024.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(public_dir, "favicon.png"))
    print("✓ 已保存 public/logo.png 与 public/favicon.png")

    # 2. Flutter App 内部 Assets
    assets_img_dir = os.path.join(base_dir, "app", "assets", "images")
    os.makedirs(assets_img_dir, exist_ok=True)
    logo_1024.save(os.path.join(assets_img_dir, "logo.png"))
    print("✓ 已保存 app/assets/images/logo.png")

    # 3. macOS 端图标
    macos_iconset = os.path.join(base_dir, "app", "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(macos_iconset):
        macos_sizes = [16, 32, 64, 128, 256, 512, 1024]
        for sz in macos_sizes:
            target = os.path.join(macos_iconset, f"app_icon_{sz}.png")
            logo_1024.resize((sz, sz), Image.Resampling.LANCZOS).save(target)
        print("✓ 已覆盖 macOS AppIcon.appiconset 全部分辨率 (16~1024)")

    # macOS 状态栏托盘图标
    tray_icons = create_mac_tray_icon()
    tray_imageset = os.path.join(base_dir, "app", "macos", "Runner", "Assets.xcassets", "StatusBarIcon.imageset")
    os.makedirs(tray_imageset, exist_ok=True)
    tray_icons[22].save(os.path.join(tray_imageset, "status_bar_icon.png"))
    tray_icons[44].save(os.path.join(tray_imageset, "status_bar_icon@2x.png"))
    with open(os.path.join(tray_imageset, "Contents.json"), "w") as f:
        f.write('''{
  "images" : [
    {
      "filename" : "status_bar_icon.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "status_bar_icon@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}''')
    print("✓ 已生成 macOS 菜单栏状态栏图标 StatusBarIcon.imageset")

    # 4. iOS 端图标
    ios_iconset = os.path.join(base_dir, "app", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_iconset):
        ios_map = {
            "Icon-App-20x20@1x.png": 20,
            "Icon-App-20x20@2x.png": 40,
            "Icon-App-20x20@3x.png": 60,
            "Icon-App-29x29@1x.png": 29,
            "Icon-App-29x29@2x.png": 58,
            "Icon-App-29x29@3x.png": 87,
            "Icon-App-40x40@1x.png": 40,
            "Icon-App-40x40@2x.png": 80,
            "Icon-App-40x40@3x.png": 120,
            "Icon-App-60x60@2x.png": 120,
            "Icon-App-60x60@3x.png": 180,
            "Icon-App-76x76@1x.png": 76,
            "Icon-App-76x76@2x.png": 152,
            "Icon-App-83.5x83.5@2x.png": 167,
            "Icon-App-1024x1024@1x.png": 1024,
        }
        for fname, sz in ios_map.items():
            target = os.path.join(ios_iconset, fname)
            logo_1024.resize((sz, sz), Image.Resampling.LANCZOS).save(target)
        print("✓ 已覆盖 iOS AppIcon.appiconset 全部分辨率 (20~1024)")

    # 5. Android 端图标
    android_res = os.path.join(base_dir, "app", "android", "app", "src", "main", "res")
    android_map = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in android_map.items():
        dirpath = os.path.join(android_res, folder)
        os.makedirs(dirpath, exist_ok=True)
        logo_1024.resize((sz, sz), Image.Resampling.LANCZOS).save(os.path.join(dirpath, "ic_launcher.png"))
    print("✓ 已覆盖 Android mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi} 全部启动图标")

    # 6. Windows 端复合 ICO 文件
    win_res = os.path.join(base_dir, "app", "windows", "runner", "resources")
    os.makedirs(win_res, exist_ok=True)
    ico_path = os.path.join(win_res, "app_icon.ico")
    # Windows 复合 ICO 包含多种尺寸
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    logo_1024.save(ico_path, format="ICO", sizes=ico_sizes)
    print("✓ 已生成 Windows 多尺寸复合图标 resources/app_icon.ico")

    # 7. Web / PWA 端图标
    web_dir = os.path.join(base_dir, "app", "web")
    web_icons = os.path.join(web_dir, "icons")
    os.makedirs(web_icons, exist_ok=True)
    logo_1024.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"))
    logo_1024.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-192.png"))
    logo_1024.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-512.png"))
    logo_1024.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-maskable-192.png"))
    logo_1024.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-maskable-512.png"))
    print("✓ 已覆盖 Web / PWA favicon 与全套 PWA 图标")

if __name__ == "__main__":
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    distribute_icons(repo_root)
    print("🎉 全平台 Logo 生成与分发覆盖完毕！")

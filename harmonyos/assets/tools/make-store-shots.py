# -*- coding: utf-8 -*-
"""出「福小外」应用市场介绍图：真机原图 + 脱敏。

不画标题、不画渐变、不加品牌胶囊，就是模拟器上截下来的那一帧：

  assets/design/store/screens/        1320x2856 真机帧（设备的原生分辨率，PNG 无损）
  assets/design/store/screens-9x16/   同一帧补边到 1080x1920（严格 9:16，AGC 上传用）
  assets/design/store/preview-10.png  10 张总览

补边只是把两侧各 96 px 填成页面底色 (247,248,251)，界面像素一点不动。

脱敏（都在原生 1320x2856 上做，不靠后期涂黑条）：
  * 「我的」页头像字母 / 姓名 / 专业 → 示例账号；
  * 「我的成绩」页每行分数与绩点 → 按 w-grade.json 里的控件坐标重写成示例分数
    （分数与绩点仍成对应关系：绩点 =（分数-50）/10）。

运行：
    "…\\dependencies\\python\\python.exe" assets/tools/make-store-shots.py

环境变量：
    FXW_LIVE  现场帧目录（默认 D:\\fxw_build\\live6，文件名为 w-*.jpeg）
"""

import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]                 # HarmonyOs/
STORE = ROOT / "assets" / "design" / "store"
OUT_RAW = STORE / "screens"
OUT_9X16 = STORE / "screens-9x16"
LIVE_DIR = Path(os.environ.get("FXW_LIVE", r"D:\fxw_build\live6"))

FONT_BD = r"C:\Windows\Fonts\msyhbd.ttc"
FONT_RG = r"C:\Windows\Fonts\msyh.ttc"

SHOT_W, SHOT_H = 1320, 2856        # 真机帧
W, H = 1080, 1920                  # 9:16 画布
PAD_BG = (247, 248, 251)
P_H = H
P_W = round(H * SHOT_W / SHOT_H)   # 887
P_LEFT = (W - P_W) // 2            # 96


def font(path, size):
    return ImageFont.truetype(path, size)


def fit_font(path, text, target_h, lo=8, hi=220):
    best = None
    for size in range(lo, hi):
        f = font(path, size)
        box = f.getbbox(text)
        d = abs((box[3] - box[1]) - target_h)
        if best is None or d < best[0]:
            best = (d, size, f)
        if box[3] - box[1] > target_h + 6:
            break
    return best[1], best[2]


def draw_text_at(draw, xy, text, f, fill):
    box = f.getbbox(text)
    draw.text((xy[0] - box[0], xy[1] - box[1]), text, font=f, fill=fill)


# ---------------------------------------------------------------- 脱敏

def anon_profile(im):
    """「我的」页：抹掉头像字母/姓名/专业，换成示例账号（同色同字号重绘）。"""
    im = im.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([96, 330, 1010, 600], fill=(255, 255, 255))

    ax0, ay0, ax1, ay1 = 106, 340, 355, 589
    gw, gh = ax1 - ax0 + 1, ay1 - ay0 + 1
    grad = Image.new("RGB", (gw, gh))
    gp = grad.load()
    c0, c1 = (65, 90, 208), (86, 108, 224)
    for y in range(gh):
        for x in range(gw):
            t = (x / gw + y / gh) / 2
            gp[x, y] = tuple(round(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
    mask = Image.new("L", grad.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, gw - 1, gh - 1], fill=255)
    im.paste(grad, (ax0, ay0), mask)

    _, f = fit_font(FONT_BD, "示", 98)
    box = f.getbbox("示")
    gw2, gh2 = box[2] - box[0], box[3] - box[1]
    cx, cy = (ax0 + ax1) / 2, (ay0 + ay1) / 2
    d.text((cx - gw2 / 2 - box[0], cy - gh2 / 2 - box[1]), "示", font=f, fill=(255, 255, 255))

    _, f = fit_font(FONT_BD, "示例同学", 90)
    draw_text_at(d, (413, 387), "示例同学", f, (26, 26, 26))
    _, f = fit_font(FONT_RG, "计算机科学与技术 · 2024级", 45)
    draw_text_at(d, (413, 498), "计算机科学与技术 · 2024级", f, (113, 116, 121))
    return im


def _ring_bg(a, box, pad=10):
    """取 bbox 外侧一圈像素的中位数，作为要填的底色（徽章底色会随分数变化）。"""
    x0, y0, x1, y1 = box
    pts = []
    for x in range(x0, x1 + 1, 4):
        pts.append(a[max(y0 - pad, 0), x])
        pts.append(a[min(y1 + pad, a.shape[0] - 1), x])
    for y in range(y0, y1 + 1, 4):
        pts.append(a[y, max(x0 - pad, 0)])
        pts.append(a[y, min(x1 + pad, a.shape[1] - 1)])
    return tuple(int(v) for v in np.median(np.array(pts), axis=0))


def _text_color(a, box):
    """bbox 内最深的那批像素的中位色 = 原字形颜色（字形总比徽章底色深）。"""
    x0, y0, x1, y1 = box
    sub = a[y0:y1 + 1, x0:x1 + 1].astype(int)
    lum = sub[:, :, 0] * 0.2126 + sub[:, :, 1] * 0.7152 + sub[:, :, 2] * 0.0722
    flat = lum.ravel()
    idx = np.argsort(flat)[:max(len(flat) // 10, 10)]
    px = sub.reshape(-1, 3)[idx]
    return tuple(int(v) for v in np.median(px, axis=0))


def anon_grade_list(im, layout):
    """把成绩列表里每行的分数与绩点换成示例值（分数/绩点仍成对应关系）。"""
    a = np.asarray(im.convert("RGB")).astype(int)
    out = im.copy()
    d = ImageDraw.Draw(out)

    scores = [n for n in layout
              if n["text"].strip().isdigit() and len(n["text"].strip()) <= 2
              and n["box"][0] > 900 and n["box"][1] > 700]
    gpas = [n for n in layout if n["text"].strip().startswith("绩点")]
    scores.sort(key=lambda n: n["box"][1])
    gpas.sort(key=lambda n: n["box"][1])

    demo = [88, 85, 91, 73, 90, 61, 72, 79, 84, 95]
    for i, n in enumerate(scores):
        box = tuple(n["box"])
        value = demo[i % len(demo)]
        bg = _ring_bg(a, box)
        fg = _text_color(a, box)
        d.rectangle([box[0] - 6, box[1] - 5, box[2] + 6, box[3] + 5], fill=bg)
        _, f = fit_font(FONT_BD, str(value), box[3] - box[1])
        bx = f.getbbox(str(value))
        cx = (box[0] + box[2]) / 2 - (bx[2] - bx[0]) / 2 - bx[0]
        cy = (box[1] + box[3]) / 2 - (bx[3] - bx[1]) / 2 - bx[1]
        d.text((cx, cy), str(value), font=f, fill=fg)

        for g in gpas:                       # 同一行的绩点（可见时一起改）
            if abs(g["box"][1] - box[3]) < 60:
                gb = tuple(g["box"])
                gbg = _ring_bg(a, gb)
                gfg = _text_color(a, gb)
                label = f"绩点 {value / 10 - 5:.1f}"
                d.rectangle([gb[0] - 4, gb[1] - 3, gb[2] + 4, gb[3] + 3], fill=gbg)
                _, gf = fit_font(FONT_RG, label, gb[3] - gb[1])
                gbx = gf.getbbox(label)
                gcx = (gb[0] + gb[2]) / 2 - (gbx[2] - gbx[0]) / 2 - gbx[0]
                gcy = (gb[1] + gb[3]) / 2 - (gbx[3] - gbx[1]) / 2 - gbx[1]
                d.text((gcx, gcy), label, font=gf, fill=gfg)
                break
    return out


# ---------------------------------------------------------------- 版面

def to_9x16(shot):
    """只补边：界面等比缩到高 1920（宽 887），左右各 96 px 填页面底色。"""
    canvas = Image.new("RGB", (W, H), PAD_BG)
    canvas.paste(shot.resize((P_W, P_H), Image.LANCZOS), (P_LEFT, 0))
    return canvas


# (输出名, 现场帧, 脱敏, 说明)
ITEMS = [
    ("01-week.png", "w-week.jpeg", None, "周课表"),
    ("02-day.png", "w-day.jpeg", None, "日视图"),
    ("03-menu.png", "w-menu.jpeg", None, "功能面板"),
    ("04-add.png", "w-add.jpeg", None, "添加课程"),
    ("05-table.png", "w-table.jpeg", None, "管理课表"),
    ("06-grade.png", "w-grade.jpeg", "grade", "我的成绩（分数已换）"),
    ("07-share.png", "w-share.jpeg", None, "分享面板"),
    ("08-calendar.png", "w-calendar.jpeg", None, "校历"),
    ("09-me.png", "w-me.jpeg", "profile", "我的（账号已脱敏）"),
    ("10-about.png", "w-about.jpeg", None, "关于与反馈"),
]


def flatten_layout(tree):
    """把 `uitest dumpLayout` 的树压平成 [{text, box}]，脱敏只认这两个字段。"""
    import re
    out = []

    def walk(n):
        a = n.get("attributes", {})
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", a.get("bounds", ""))
        out.append({"text": (a.get("text") or "").strip(),
                    "box": tuple(map(int, m.groups())) if m else None})
        for c in n.get("children") or []:
            walk(c)

    if tree:
        walk(tree)
    return [n for n in out if n["box"]]


def main():
    layout_path = LIVE_DIR / "w-grade.json"
    layout = flatten_layout(json.loads(layout_path.read_text(encoding="utf-8"))) \
        if layout_path.exists() else []

    for d in (OUT_RAW, OUT_9X16):
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob("*.png"):
            old.unlink()
    for old in STORE.glob("preview-*.png"):
        old.unlink()

    made = []
    for name, src, mode, note in ITEMS:
        path = LIVE_DIR / src
        if not path.exists():
            raise SystemExit(f"缺图：{path}")
        shot = Image.open(path).convert("RGB")
        if shot.size != (SHOT_W, SHOT_H):
            raise SystemExit(f"{path.name} 尺寸 {shot.size}，应为 {(SHOT_W, SHOT_H)}")
        if mode == "profile":
            shot = anon_profile(shot)
        elif mode == "grade":
            if not layout:
                raise SystemExit(f"缺布局：{layout_path}（成绩页脱敏需要控件坐标）")
            shot = anon_grade_list(shot, layout)

        raw = OUT_RAW / name
        shot.save(raw, "PNG", optimize=True)
        pad = OUT_9X16 / name
        to_9x16(shot).save(pad, "PNG", optimize=True)
        made.append((name, note, shot.size, raw.stat().st_size, pad.stat().st_size))

    tw = 264
    th = round(tw * SHOT_H / SHOT_W)
    gap, cap_h = 22, 54
    lw = 5 * tw + 6 * gap
    lh = 2 * (th + cap_h) + 3 * gap
    lab = Image.new("RGB", (lw, lh), (238, 242, 250))
    dr = ImageDraw.Draw(lab)
    fnum, fcap = font(FONT_BD, 26), font(FONT_RG, 24)
    for i, (name, note, _, _, _) in enumerate(made):
        tile = Image.open(OUT_9X16 / name).resize((tw, th), Image.LANCZOS)
        x = gap + (i % 5) * (tw + gap)
        y = gap + (i // 5) * (th + cap_h + gap)
        lab.paste(tile, (x, y))
        dr.text((x + 2, y + th + 14), f"{i + 1:02d}", font=fnum, fill=(120, 132, 160))
        dr.text((x + 46, y + th + 15), note, font=fcap, fill=(38, 42, 52))
    lab.save(STORE / "preview-10.png", "PNG", optimize=True)

    print(f"frames={LIVE_DIR}")
    for name, note, size, nraw, npad in made:
        print(f"{name:14s} 原图 {size[0]}x{size[1]} {nraw/1024:7.1f} KB | 9:16 {npad/1024:7.1f} KB  {note}")
    print(f"preview-10.png {lab.size[0]}x{lab.size[1]}")


if __name__ == "__main__":
    main()
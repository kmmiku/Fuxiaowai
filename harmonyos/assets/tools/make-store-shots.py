# -*- coding: utf-8 -*-
"""生成「福小外」应用市场介绍图（10 张，1080x1920，9:16）。

样式与仓库里原有的介绍图一致（assets/design/store/screens/01-home.png）：
    浅蓝渐变底  +  顶部品牌胶囊  +  一行标题  +  一行副标题  +  圆角带阴影的界面截图

画面内容用的是 2026-11-14 在当前构建上现场抓的真机帧（1320x2856），
所以「图是渲染的、界面是当前的」，与设备上看到的一致。

几何全部从参考图实测：卡片 x=198..881（宽 684）、y=300..1780（高 1480）、圆角 46、
阴影高斯 26；标题字形高 58（顶部 y=178）、副标题高 28（顶部 y=254）、
品牌胶囊 x=457..623、y=67..127（直接从参考图裁下来贴，保证图标与字一模一样）。

运行：
    "C:\\Users\\Administrator\\.dsh\\dsh-runtimes\\dsh-primary-runtime\\dependencies\\python\\python.exe" \
        assets/tools/make-store-shots.py

环境变量 FXW_LIVE 指定现场帧目录（默认 D:\\fxw_build\\live2，文件名为 r-*.jpeg）。
"""

import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]                 # HarmonyOs/
OUT_DIR = ROOT / "assets" / "design" / "store" / "screens"
STORE = ROOT / "assets" / "design" / "store"
LIVE_DIR = Path(os.environ.get("FXW_LIVE", r"D:\fxw_build\live2"))
REF = Path(os.environ.get("FXW_REF", r"D:\fxw_build\Fuxiaowai\assets\design\store\screens\01-home.png"))

FONT_BD = r"C:\Windows\Fonts\msyhbd.ttc"
FONT_RG = r"C:\Windows\Fonts\msyh.ttc"

W, H = 1080, 1920                  # 画布
CARD_W, CARD_H, CARD_TOP = 684, 1480, 300
CARD_X = (W - CARD_W) // 2         # 198
RADIUS = 46
TITLE_TOP, TITLE_H = 178, 58
SUB_TOP, SUB_H = 254, 28
C_TITLE = (15, 23, 42)
C_SUB = (95, 104, 118)


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


def draw_centered(draw, cy_top, text, f, fill):
    box = f.getbbox(text)
    w = box[2] - box[0]
    draw_text_at(draw, ((W - w) // 2, cy_top), text, f, fill)


# ---------------------------------------------------------------- 背景

def background(ref):
    """按参考图逐行在左右两侧像素之间插值，复刻「左上更蓝、右下更白」的渐变。"""
    a = np.asarray(ref.convert("RGB")).astype(np.float32)
    left = a[:, 3]                       # 左边缘
    right = a[:, W - 4]                  # 右边缘
    t = np.linspace(0.0, 1.0, W, dtype=np.float32)[None, :, None]
    grad = left[:, None, :] * (1 - t) + right[:, None, :] * t
    return Image.fromarray(np.clip(grad, 0, 255).astype(np.uint8))


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


# ---------------------------------------------------------------- 卡片

def round_mask(size, radius, ss=4):
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def paste_card(canvas, shot):
    """把 1320x2856 的真机帧贴进 684x1480、圆角 46、带柔和阴影的卡片位置。"""
    card = shot.resize((CARD_W, CARD_H), Image.LANCZOS)
    mask = round_mask((CARD_W, CARD_H), RADIUS)

    # 阴影：卡片轮廓模糊后压一层淡蓝灰
    sh = Image.new("L", (W, H), 0)
    sh.paste(mask, (CARD_X, CARD_TOP + 10))
    sh = sh.filter(ImageFilter.GaussianBlur(26))
    shade = Image.new("RGB", (W, H), (60, 80, 140))
    canvas.paste(shade, (0, 0), sh.point(lambda v: int(v * 0.42)))

    canvas.paste(card, (CARD_X, CARD_TOP), mask)
    return canvas


# ---------------------------------------------------------------- 清单

# (输出名, 现场帧, 脱敏函数, 标题, 副标题)
ITEMS = [
    ("01-week.png", "r-week.jpeg", None, "一周课表，一眼看清", "周一到周日，课程按颜色分开"),
    ("02-course.png", "r-course.jpeg", None, "点开就是一节课的全部", "周次、时间、地点、教师，一眼看全"),
    ("03-add.png", "r-add.jpeg", None, "手动添加课程", "星期、节次、周次随手选"),
    ("04-import.png", "r-login4.jpeg", None, "登录一次，课表自动同步", "每天首次打开自动更新，不用手抄"),
    ("05-share.png", "r-share.jpeg", None, "课表分享给同学", "导出到系统日历，也能用口令导入"),
    ("06-calendar.png", "r-calendar.jpeg", None, "校历随时翻", "两个学期一键切换，节假日标出来"),
    ("07-reminder.png", "r-reminder2.jpeg", None, "上课前提醒一次", "提前 5–30 分钟可选，退到后台也响"),
    ("08-me.png", "r-me.jpeg", anon_profile, "账号与外观", "课表设置、提醒、账号安全都在这里"),
    ("09-menu.png", "r-menu.jpeg", None, "换周、换学期，一步到位", "周数一拖就跳，八个入口一眼找到"),
    ("10-dark.png", "r-dark4.jpeg", None, "晚上看也不刺眼", "深色课表，晚自习也舒服"),
]


def main():
    ref = Image.open(REF).convert("RGB")
    if ref.size != (W, H):
        raise SystemExit(f"参考图尺寸 {ref.size}，应为 {(W, H)}")
    bg = background(ref)
    pill = ref.crop((445, 56, 637, 140))      # 品牌胶囊：直接沿用参考图那块像素

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("*.png"):
        old.unlink()
    for old in (STORE / "preview-10.png", STORE / "preview-labeled.png"):
        if old.exists():
            old.unlink()

    made = []
    for name, src, fn, title, sub in ITEMS:
        path = LIVE_DIR / src
        if not path.exists():
            raise SystemExit(f"缺图：{path}")
        shot = Image.open(path).convert("RGB")
        if shot.size != (1320, 2856):
            raise SystemExit(f"{path.name} 尺寸 {shot.size}，应为 (1320, 2856)")
        if fn:
            shot = fn(shot)

        canvas = bg.copy()
        paste_card(canvas, shot)
        d = ImageDraw.Draw(canvas)
        canvas.paste(pill, (445, 56))

        _, ft = fit_font(FONT_BD, title, TITLE_H)
        draw_centered(d, TITLE_TOP, title, ft, C_TITLE)
        _, fs = fit_font(FONT_RG, sub, SUB_H)
        draw_centered(d, SUB_TOP, sub, fs, C_SUB)

        out = OUT_DIR / name
        canvas.save(out, "PNG", optimize=True)
        made.append((out, title, canvas.size, out.stat().st_size))

    # 界面预览：5 列 x 2 行，带序号+标题
    tw, th, gap, cap_h = 396, 704, 26, 62
    lw = 5 * tw + 6 * gap
    lh = 2 * (th + cap_h) + 3 * gap
    lab = Image.new("RGB", (lw, lh), (238, 242, 250))
    dr = ImageDraw.Draw(lab)
    fnum, fcap = font(FONT_BD, 28), font(FONT_RG, 26)
    for i, (out, title, _, _) in enumerate(made):
        tile = Image.open(out).resize((tw, th), Image.LANCZOS)
        x = gap + (i % 5) * (tw + gap)
        y = gap + (i // 5) * (th + cap_h + gap)
        lab.paste(tile, (x, y))
        dr.text((x + 4, y + th + 16), f"{i + 1:02d}", font=fnum, fill=(120, 132, 160))
        dr.text((x + 52, y + th + 17), title, font=fcap, fill=(38, 42, 52))
    lab.save(STORE / "preview-labeled.png", "PNG", optimize=True)

    # 纯拼图
    sheet = Image.new("RGB", (5 * tw + 6 * 8, 2 * th + 3 * 8), (255, 255, 255))
    for i, (out, _, _, _) in enumerate(made):
        tile = Image.open(out).resize((tw, th), Image.LANCZOS)
        sheet.paste(tile, (8 + (i % 5) * (tw + 8), 8 + (i // 5) * (th + 8)))
    sheet.save(STORE / "preview-10.png", "PNG", optimize=True)

    for out, title, size, nbytes in made:
        print(f"{out.name:16s} {size[0]}x{size[1]}  {nbytes/1024:7.1f} KB  {title}")
    print(f"preview-labeled  {lab.size[0]}x{lab.size[1]}")


if __name__ == "__main__":
    main()
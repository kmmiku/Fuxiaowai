# -*- coding: utf-8 -*-
"""重建「福小外 · 华为应用市场审核自测说明」。

以原文档为模板（沿用页面设置、页脚页码、TableGrid 样式），清空正文后按当前
构建的真实界面重写文字，并把 10 张商店介绍图（assets/design/store/screens）
作为文中配图。图片与文字一一对应，不再保留已失效的旧截图。
"""

import sys
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Emu, Pt, RGBColor

SRC = Path(r"D:\fxw_build\docx\src.docx")
OUT = Path(r"D:\fxw_build\docx\out.docx")
SHOTS = Path(r"D:\DSH_Wrodkstation\Homework\机器学习\福小外\HarmonyOs\assets\design\store\screens")

FONT = "微软雅黑"
C_TITLE = "1A1A1A"
C_BRAND = "1F3B8A"
C_GREY = "555555"
C_NOTE = "666666"
C_HEAD = "3E6FE0"

IMG_H = 3657600
IMG_W = round(IMG_H * 1080 / 1920)
IMG_H_S = 3017520  # 单图（无并排）稍小，便于与正文同页
IMG_W_S = round(IMG_H_S * 1080 / 1920)


def set_run(run, size=None, bold=None, color=None, font=FONT):
    run.font.name = font
    rpr = run._element.get_or_add_rPr()
    rf = rpr.find(qn("w:rFonts"))
    if rf is None:
        rf = OxmlElement("w:rFonts")
        rpr.insert(0, rf)
    for attr in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
        rf.set(qn(attr), font)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.font.bold = bold
    if color is not None:
        run.font.color.rgb = RGBColor.from_string(color)


def para(doc, text="", size=10.5, bold=False, color=None, align=None,
         before=0, after=40, style=None, border=None, keep_next=False,
         line=None, page_break=False):
    p = doc.add_paragraph(style=style)
    pf = p.paragraph_format
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)
    if line:
        pf.line_spacing = line
    if align is not None:
        p.alignment = align
    if keep_next:
        p.paragraph_format.keep_with_next = True
    if border:
        pbdr = OxmlElement("w:pBdr")
        bottom = OxmlElement("w:bottom")
        bottom.set(qn("w:val"), "single")
        bottom.set(qn("w:sz"), "8")
        bottom.set(qn("w:space"), "4")
        bottom.set(qn("w:color"), border)
        pbdr.append(bottom)
        p._p.get_or_add_pPr().append(pbdr)
    if page_break:
        p.paragraph_format.page_break_before = True
    if text:
        set_run(p.add_run(text), size=size, bold=bold, color=color)
    return p


def h1(doc, text, page_break=False):
    return para(doc, text, size=15, bold=True, color=C_TITLE, before=13, after=6,
                border=C_HEAD, keep_next=True, page_break=page_break)


def h3(doc, text):
    return para(doc, text, size=12, bold=True, color="242424", before=9, after=3,
                keep_next=True)


def body(doc, text, before=0, after=2):
    return para(doc, text, size=10.5, bold=False, before=before, after=after)


def bullet(doc, text, lead=None):
    p = doc.add_paragraph(style="List Bullet")
    pf = p.paragraph_format
    pf.space_after = Pt(1)
    pf.line_spacing = 1.3
    if lead:
        set_run(p.add_run(lead), size=10.5, bold=True)
    set_run(p.add_run(text), size=10.5, bold=False)
    return p


def shade(cell, hex_fill):
    tcpr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:fill"), hex_fill)
    tcpr.append(shd)


def cell_text(cell, text, size=10, bold=False, color=None, align=WD_ALIGN_PARAGRAPH.LEFT):
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.2
    p.alignment = align
    parts = str(text).split("\n")
    run = p.add_run(parts[0])
    set_run(run, size=size, bold=bold, color=color)
    for extra in parts[1:]:
        run.add_break()
        run.add_text(extra)


def _fix_grid(t, widths):
    """固定列宽：同时写 tblLayout / tblW / tblGrid，LibreOffice 与 Word 一致。"""
    tbl = t._tbl
    tbl_pr = tbl.tblPr
    for tag in ("w:tblLayout", "w:tblW"):
        for el in tbl_pr.findall(qn(tag)):
            tbl_pr.remove(el)
    layout = OxmlElement("w:tblLayout")
    layout.set(qn("w:type"), "fixed")
    tbl_pr.append(layout)
    tbl_w = OxmlElement("w:tblW")
    tbl_w.set(qn("w:type"), "dxa")
    tbl_w.set(qn("w:w"), str(sum(widths)))
    tbl_pr.append(tbl_w)
    grid = tbl.find(qn("w:tblGrid"))
    if grid is not None:
        for gc, w in zip(grid.findall(qn("w:gridCol")), widths):
            gc.set(qn("w:w"), str(int(w)))


def table(doc, rows, widths, header=True, size=10, head_size=10):
    t = doc.add_table(rows=0, cols=len(widths))
    t.style = "TableGrid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    _fix_grid(t, widths)
    for r_i, row in enumerate(rows):
        tr = t.add_row()
        if header and r_i == 0:
            tr._tr.get_or_add_trPr().append(OxmlElement("w:tblHeader"))
        for c_i, val in enumerate(row):
            cell = tr.cells[c_i]
            cell.width = Emu(int(widths[c_i] * 914400 / 1440))
            if header and r_i == 0:
                shade(cell, C_HEAD)
                cell_text(cell, val, size=head_size, bold=True, color="FFFFFF",
                          align=WD_ALIGN_PARAGRAPH.CENTER)
            else:
                cell_text(cell, val, size=size)
    return t


def _figure(doc, name, caption):
    """单图：无边框居中，图 + 图注。"""
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    p.add_run().add_picture(str(SHOTS / name), width=Emu(IMG_W_S), height=Emu(IMG_H_S))
    cp = doc.add_paragraph()
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cp.paragraph_format.space_after = Pt(8)
    set_run(cp.add_run(caption), size=8, bold=False, color=C_GREY)


def shots_table(doc, items):
    """items: [(截图文件名, 说明), ...]

    成对的两张并排放进两列表格；落单的一张用无边框居中单图，避免出现空白单元格。
    """
    paired = len(items) - len(items) % 2
    if paired:
        t = doc.add_table(rows=0, cols=2)
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = False
        for i in range(0, paired, 2):
            tr = t.add_row()
            # 整行不跨页，图片与图注留在同一页
            tr_pr = tr._tr.get_or_add_trPr()
            tr_pr.append(OxmlElement("w:cantSplit"))
            for j in range(2):
                cell = tr.cells[j]
                cell.width = Emu(4762 * 635)
                name, caption = items[i + j]
                p = cell.paragraphs[0]
                p.paragraph_format.space_before = Pt(3)
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.keep_with_next = True
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                p.add_run().add_picture(str(SHOTS / name), width=Emu(IMG_W), height=Emu(IMG_H))
                cp = cell.add_paragraph()
                cp.paragraph_format.space_after = Pt(3)
                cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
                set_run(cp.add_run(caption), size=8, bold=False, color=C_GREY)
    for name, caption in items[paired:]:
        _figure(doc, name, caption)
    return None


def main():
    doc = Document(str(SRC))

    # 清空正文，保留最后一个 sectPr（页面设置 + 页脚引用）
    body_el = doc.element.body
    sect_pr = body_el.find(qn("w:sectPr"))
    for child in list(body_el):
        if child is not sect_pr:
            body_el.remove(child)

    # ------------------------------------------------------------------ 封面
    para(doc, "福 小 外", size=34, bold=True, color=C_BRAND,
         align=WD_ALIGN_PARAGRAPH.CENTER, after=6)
    para(doc, "课表同步 · 校历 · 成绩 · 上课提醒 · 桌面小组件", size=12, bold=False,
         color=C_GREY, align=WD_ALIGN_PARAGRAPH.CENTER, after=28)
    para(doc, "华为应用市场审核自测说明", size=22, bold=True, color=C_TITLE,
         align=WD_ALIGN_PARAGRAPH.CENTER, after=6)
    para(doc, "HarmonyOS 版本 v0.1.1　·　10 张截图为当前构建真机截图，个人信息已脱敏",
         size=11, bold=False, color="777777", align=WD_ALIGN_PARAGRAPH.CENTER, after=54)

    table(doc, [
        ["项目", "内容"],
        ["应用名称", "福小外"],
        ["应用包名", "com.fuxiaowai.timetable"],
        ["版本号", "0.1.0"],
        ["运行平台", "HarmonyOS（API 26）"],
        ["开发者", "李立翔（个人开发者，非学校官方应用）"],
        ["文档用途", "供审核人员逐屏核对功能、权限与数据处理方式"],
        ["截图说明", "10 张，取自当前构建真机运行画面；姓名、学号、专业、成绩已替换为示例数据"],
        ["文档日期", "2026 年 11 月 15 日"],
    ], widths=[2200, 7500])

    para(doc, "", after=8)
    para(doc, "阅读提示：本文档按「功能说明 → 截图 → 每图一句话」组织。文中截图取自当前构建"
              "（v0.1.1）的真机运行画面，非设计稿、非渲染图；图中的姓名、学号、专业与成绩已替换为"
              "示例数据，课程名与教师名保留原样（属公开课表信息）。第 2 章说明测试环境与「无需登录"
              "即可核对」的范围，第 3 章为功能索引，第 4 – 12 章逐屏说明，第 13 章为权限，第 14 章为"
              "数据处理，第 15 章为审核可能关注的问题。",
         size=9.5, bold=False, color=C_NOTE, after=2)

    # ------------------------------------------------------------------ 1
    h1(doc, "1　文档说明")
    body(doc, "本应用是面向福州外语外贸学院学生的课表工具：学生用本人学号登录学校教务系统，把课表、"
              "成绩、考试安排同步到手机本地查看，并提供上课提醒、校历、桌面小组件、课表口令分享等辅助"
              "功能。先说明四件事：")
    para(doc, "", after=1)
    bullet(doc, "首页支持手动添加课程，校历、上课提醒、外观设置可直接使用，并可用示例口令导入一份完整"
                "课表（见 2.2）。审核无需任何账号即可核对课表排布、节次、日 / 周视图、校历、提醒与外观等界面。",
           lead="无需登录即可体验大部分界面。")
    bullet(doc, "学校教务系统（正方，jw.fzfu.edu.cn）仅对校内网络开放，其中包含在校学生的真实成绩与身份"
                "信息，因此不提供测试账号。此限制来自学校，不是应用功能缺失。",
           lead="课表同步、成绩查询与考试安排需要学生本人的学号与教务密码。")
    bullet(doc, "登录后同步的课表、成绩、个人资料全部保存在手机本地；只有「课表口令分享」与「反馈问题」"
                "两个由用户主动发起的操作，会把对应内容发送到服务端。第 14 章逐项列明。",
           lead="数据保存在本地。")
    bullet(doc, "无广告、无内购、无社交与公开内容，不设任何用户生成内容的公开展示入口。",
           lead="应用性质。")

    # ------------------------------------------------------------------ 2
    h1(doc, "2　测试环境与测试账号")
    table(doc, [
        ["项目", "说明"],
        ["测试设备", "华为鸿蒙设备 / DevEco 模拟器（API 26，1320 × 2856）"],
        ["安装包", "fuxiaowai-timetable-0.1.0.hap（hdc install 安装）"],
        ["网络环境", "教务系统需校内网络；课表浏览、校历、上课提醒、口令导入在任意网络下可用"],
        ["数据来源", "正方教务系统 jw.fzfu.edu.cn（学校官方系统）"],
        ["登录状态", "截图为开发者本人设备的现场截屏；图中姓名、专业已替换为示例数据"],
        ["测试账号", "不提供。教务系统仅对校内开放且含在校学生隐私，账号由学校分配，无法对外提供"],
        ["无账号体验", "手动添加课程 + 校历 + 上课提醒 + 示例口令导入课表（见 2.1、2.2）"],
    ], widths=[2200, 7500])

    h3(doc, "2.1　审核无需登录即可核对的内容")
    body(doc, "不登录教务系统时，下列界面均可正常打开与操作：", before=4)
    para(doc, "", after=1)
    bullet(doc, "手动添加课程（课程名、教师、教室、校区、星期、节次、周次、颜色），保存后立即按节次"
                "排布到周视图；可切换周 / 日视图、拖动周数滑杆跳周。", lead="首页课表：")
    bullet(doc, "按学期展示教学周、节假日与开学/考试等关键节点，可切换第一 / 第二学期。", lead="校历：")
    bullet(doc, "选择提前 5 / 10 / 15 / 30 分钟，按本周课表批量生成系统提醒（首次生成时申请通知权限）。",
           lead="上课提醒：")
    bullet(doc, "粘贴 2.2 的示例口令，即可获得一份完整课表（含课程名、地点、教师、节次与周次），"
                "用于核对课表渲染效果。", lead="课表口令导入：")
    bullet(doc, "主题色、夜间模式、课表格子高度、上课时间等，均可直接调整并即时预览。", lead="外观与设置：")

    h3(doc, "2.2　示例口令（无需登录，用于核对课表渲染）")
    body(doc, "在首页点「↗」→「从口令导入」，粘贴下面这串口令并确认，即可导入一份示例课表"
              "（会覆盖当前课表，可随后在功能面板中清除）：", before=4)
    p = para(doc, "e4c662fc53813b31e040cffae07d871b", size=12, bold=True, color=C_BRAND,
             align=WD_ALIGN_PARAGRAPH.CENTER, before=6, after=6, font=None) if False else None
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(6)
    set_run(p.add_run("e4c662fc53813b31e040cffae07d871b"), size=12, bold=True,
            color=C_BRAND, font="Consolas")
    body(doc, "导入后可见完整课表与节次，用于核对周 / 日视图、课程块配色与课程详情弹层。口令只包含"
              "课程名、地点、教师、节次与周次，不含任何身份信息，服务端 30 天后自动失效。")

    # ------------------------------------------------------------------ 3
    h1(doc, "3　功能总览")
    table(doc, [
        ["模块", "入口位置", "是否需要登录", "章节"],
        ["首次登录 / 导入课表", "首页顶部「⇩」", "需要", "4"],
        ["课表周视图 / 日视图", "底部「课程」标签；顶部「日 / 周」", "不需要", "5"],
        ["课程详情 / 添加课程", "点课程块；顶部「＋」", "不需要", "5"],
        ["换周 / 功能面板", "顶部「⋯」", "不需要", "5"],
        ["切换学期 / 新建与管理课表", "功能面板", "需要（学期来自教务系统）", "5"],
        ["上课时间 / 课表设置 / 主题 / 夜间模式", "功能面板 8 个入口", "不需要", "5"],
        ["校历", "底部「校历」标签", "不需要", "6"],
        ["成绩与考试安排", "底部「我的成绩」标签", "需要", "7"],
        ["课表口令分享 / 从口令导入", "顶部「↗」", "不需要（可用示例口令）", "8"],
        ["导出到系统日历 / 上课提醒", "功能面板；「我的」→ 上课提醒", "不需要", "9"],
        ["个人资料 / 反馈 / 账号安全 / 常见问题 / 关于", "「我的」各入口", "部分需要", "10"],
        ["隐私与数据（5 个入口）", "「我的」→ 更多", "不需要", "11"],
        ["桌面小组件", "桌面长按图标 → 卡片", "不需要", "12"],
        ["权限使用说明", "系统权限弹窗", "—", "13"],
    ], widths=[2700, 2600, 2200, 2200], size=9, head_size=9)

    # ------------------------------------------------------------------ 4
    h1(doc, "4　首次使用与登录")
    body(doc, "首页顶部「⇩」进入「导入课表」：输入学号与教务密码，选择「教务登录入口」或「教学综合平台"
              "入口」（学校两套系统地址不同、数据一致），点「登录并导入课表」即可拉取本学期课表。"
              "「记住密码（用于定期更新课表）」与「每天自动更新课表」为可选开关，不勾选也能正常使用；"
              "凭据只写入应用私有目录，不上传服务端。")
    body(doc, "下图为登录页未填写状态：学号与教务密码为空，仅显示输入提示。不登录时该页可直接返回，"
              "不影响课表浏览、校历与提醒等功能。", before=4)
    shots_table(doc, [("04-import.png",
                       "导入课表 · 教务登录：学号 + 教务密码，可选登录入口、记住密码、每天自动更新课表")])
    body(doc, "登录失败时，「我的 → 网络检测」会分别探测教务系统与本应用服务端是否可达，用于区分"
              "「校内网络未接入」与「教务系统维护」。该功能只发送两次普通 HTTP 请求，不读取 Wi-Fi 名称、"
              "MAC 地址，也不获取任何位置信息。", before=6)

    # ------------------------------------------------------------------ 5
    h1(doc, "5　课表")
    body(doc, "课表是主界面。顶部为当前周次与本周日期，右侧依次是「日 / 周」切换、「＋」添加课程、"
              "「⇩」导入课表、「↗」分享与口令、「⋯」功能面板；底部为 校历 / 课程 / 我的成绩 / 我的 四个标签。")
    shots_table(doc, [
        ("01-week.png", "周视图：顶部显示当前周次与本周日期，课程块按节次排布，颜色区分课程，当天日期高亮"),
        ("09-menu.png", "功能面板：周数滑杆可直接跳周；下方为切换 / 新建 / 管理课表，以及上课时间、"
                        "课表设置、上课提醒、小组件、联系我们、主题设置、夜间模式、检查更新 8 个入口"),
        ("02-course.png", "课程详情：周次、时间、地点、教师，支持编辑 / 复制 / 删除"),
        ("03-add.png", "添加课程：课程名、教师、教室、校区、星期、节次、周次与颜色，保存后立即出现在课表（无需登录）"),
        ("10-dark.png", "夜间模式：深色课表，文字与课程块对比度保持可读，晚自习查看不刺眼"),
    ])
    body(doc, "手动添加的课程只保存在本机；从教务系统同步的课程带「非本周」等状态标记，切换周次时按"
              "范围显示或隐藏。课表格子高度、是否显示非本周课程在「功能面板 → 课表设置」中调整，"
              "修改时右侧实时预览。", before=6)

    # ------------------------------------------------------------------ 6
    h1(doc, "6　校历")
    body(doc, "校历按学期展示教学周与关键节点（开学、国庆假期、考试周等），顶部可切换第一 / 第二学期，"
              "红圈为当天。校历数据随学期同步更新；未登录时展示内置的学期框架，不依赖账号。")
    shots_table(doc, [("06-calendar.png",
                       "校历：按学期展示教学周、节假日与关键节点，红圈为当天")])

    # ------------------------------------------------------------------ 7
    h1(doc, "7　成绩与考试安排")
    body(doc, "成绩页汇总加权平均分、平均绩点、已修学分与不及格门数，并按学期筛选逐门成绩；右上角"
              "「考试安排」跳转教务系统的考试安排页面。成绩与绩点由应用在本地按学校公开的学分与绩点"
              "对应关系计算，仅供参考，最终以教务系统为准；应用不对成绩做任何修改或回写。")
    body(doc, "本章不附图：成绩页的数据必须由学生本人登录教务系统后才有内容，未登录时仅显示"
              "「还没有保存教务账号」的空态。为避免使用他人成绩、或使用与当前构建不一致的历史截图，"
              "本章只作文字说明。审核如需核对这一屏，可联系开发者获取录屏（见 15.5）。", before=4)

    # ------------------------------------------------------------------ 8
    h1(doc, "8　课表分享与导入（口令机制）")
    body(doc, "分享由用户主动发起：首页「↗」弹出「分享课表 / 导出到日程 / 从口令导入」，选择「分享课表」"
              "生成 32 位随机口令与分享文案并复制到剪贴板；收到口令的同学在「从口令导入」中粘贴口令，"
              "查询后覆盖为自己的课表。口令只包含课程名、地点、教师、节次与周次，不含姓名、学号、成绩等"
              "身份信息，30 天后自动失效。")
    shots_table(doc, [("05-share.png",
                       "分享面板：分享课表 / 导出到日程 / 从口令导入，三个入口都在首页「↗」")])
    body(doc, "为便于在无账号状态下核对课表渲染，可用 2.2 的示例口令导入一份示例课表；导入内容同样是"
              "「课程名 + 地点 + 教师 + 节次 + 周次」，不含任何身份信息。", before=6)

    # ------------------------------------------------------------------ 9
    h1(doc, "9　导出到系统日历与上课提醒")
    body(doc, "两个功能都与「日程」相关，均可单独关闭。导出到系统日历把本学期课程写入系统日历，可选是否"
              "提前提醒及提前时长，写入前先读取日历判断是否已存在，避免重复；上课提醒按本周课表批量生成"
              "提醒，提前时间可选 5 / 10 / 15 / 30 分钟，通过系统通知与代理提醒能力投递。两者分别需要日历"
              "读写权限与通知权限，拒绝授权均不影响课表本身。")
    shots_table(doc, [("07-reminder.png",
                       "上课提醒：开启后选择提前时间，一键按本周课表生成提醒；退到后台仍会响")])

    # ------------------------------------------------------------------ 10
    h1(doc, "10　我的")
    body(doc, "「我的」聚合个人资料、反馈问题、课表设置、上课提醒、外观、账号与安全，以及常见问题、"
              "关于福小外、清除缓存、网络检测与更多。个人资料中的姓名、学号、专业、班级、年级来自教务"
              "系统同步结果，应用内只读，需在教务系统修改后重新同步；头像为用户自选图片，仅存本机。"
              "反馈可提交文字（最多 500 字）与最多 3 张图片，联系方式为必填项，同一网络地址 30 分钟内"
              "只允许提交一次；除联系方式外不采集机型、序列号、广告标识等设备信息。")
    shots_table(doc, [("08-me.png",
                       "我的：个人资料卡（图中姓名与专业已替换为示例数据）、反馈问题、课表设置、"
                       "上课提醒、外观、账号与安全等入口")])

    # ------------------------------------------------------------------ 11
    h1(doc, "11　隐私与数据（应用内 5 个入口）")
    body(doc, "「我的」→ 更多 中提供五个隐私相关入口，均可在应用内直接访问，无需跳转浏览器：")
    para(doc, "", after=1)
    bullet(doc, "逐项列出收集的信息、用途与存放位置。", lead="个人信息收集清单：")
    bullet(doc, "列出仅与学校教务系统交互的信息范围。", lead="第三方信息共享清单：")
    bullet(doc, "把本机保存的个人信息导出为 JSON 并复制到剪贴板。", lead="个人信息导出：")
    bullet(doc, "逐项说明已申请权限的用途与当前状态，可按需关闭。", lead="权限中心：")
    bullet(doc, "撤回同意为不可撤销操作，执行后本机课表、成绩、个人资料、凭据与反馈记录一并清除，"
                "并回到未登录状态。", lead="隐私协议撤回：")

    # ------------------------------------------------------------------ 12
    h1(doc, "12　桌面小组件")
    body(doc, "在桌面长按应用图标选择「卡片」，挑选「今天的课」并添加至桌面；小组件无需打开应用即可"
              "显示当天课程、节次时间与教室，数据与应用内课表同源，不额外采集任何信息。")
    body(doc, "本章不附图：卡片需由用户在桌面手动添加，截图环境（模拟器桌面）未安装卡片。添加方式与"
              "展示内容如上，如需动态核对可联系开发者获取录屏（见 15.5）。", before=4)

    # ------------------------------------------------------------------ 13
    h1(doc, "13　权限使用说明")
    body(doc, "应用共声明 4 项权限，均在首次触发对应功能时申请，拒绝授权不影响课表查看等基本功能。")
    table(doc, [
        ["权限", "用途", "触发时机", "拒绝后的结果"],
        ["ohos.permission.\nINTERNET", "访问学校教务系统、同步课表与成绩", "首次同步 / 登录", "无法同步，仍可查看已有课表"],
        ["ohos.permission.\nPUBLISH_AGENT_REMINDER", "投递上课提醒（代理提醒）", "在「上课提醒」中生成提醒时", "不产生提醒，课表正常"],
        ["ohos.permission.\nREAD_CALENDAR", "导出前检查日历是否已有该课程，避免重复写入", "使用「导出到日程」时", "导出功能不可用"],
        ["ohos.permission.\nWRITE_CALENDAR", "把课程写入系统日历", "使用「导出到日程」时", "导出功能不可用"],
    ], widths=[3400, 2900, 1700, 1700], size=8.5, head_size=9)

    body(doc, "首次使用「导出到日程」或「上课提醒」时会分别弹出日历与通知权限申请；两者都只服务于"
              "「把课表写成日程」和「上课前提醒」，不用于任何其他用途。", before=6)
    para(doc, "另有两类能力按需使用、不占用常驻权限：", size=10.5, bold=True, before=5, after=2)
    para(doc, "", after=1)
    bullet(doc, "添加反馈图片、更换头像时调用系统图片选择器（PhotoViewPicker），只读取用户本次选中的"
                "图片，未声明相册常驻读取权限。", lead="图片选择：")
    bullet(doc, "反馈中附加文件时调用系统文件选择器（DocumentViewPicker），同样只读取用户选中的文件。",
           lead="文档选择：")
    body(doc, "应用未申请定位、通讯录、短信、通话记录、麦克风、摄像头、设备标识（OAID / ODID / IMEI / "
              "MAC）等任何权限，也未读取 Wi-Fi 名称或 MAC 地址。", before=6)

    h3(doc, "13.1　权限与用户可见功能的对应关系")
    table(doc, [
        ["用户可见功能", "涉及的权限 / 能力", "是否必需"],
        ["查看课表、校历、手动添加课程", "无", "—"],
        ["登录并同步课表 / 成绩", "INTERNET + 校内网络", "必需（该功能）"],
        ["上课提醒", "PUBLISH_AGENT_REMINDER + 通知", "可选"],
        ["导出到系统日历", "READ_CALENDAR + WRITE_CALENDAR", "可选"],
        ["分享课表 / 从口令导入", "INTERNET", "可选"],
        ["反馈问题（含图片）", "INTERNET + 系统图片选择器", "可选"],
    ], widths=[3000, 4300, 2400], size=9, head_size=9)

    # ------------------------------------------------------------------ 14
    h1(doc, "14　数据处理说明")
    h3(doc, "14.1　数据流向")
    table(doc, [
        ["数据类型", "产生方式", "存放位置", "是否发送到服务端"],
        ["学号、教务密码", "用户登录时输入", "手机本地应用私有目录", "否（仅发送给学校教务系统用于登录）"],
        ["姓名、学号、专业、班级、年级", "从教务系统同步", "手机本地", "否"],
        ["课程表、成绩、考试安排", "从教务系统同步 / 手动添加", "手机本地", "仅在用户主动「分享课表」时发送课程内容（不含身份信息）"],
        ["上课时间、外观等设置", "用户设置", "手机本地", "否"],
        ["反馈文字、图片、联系方式", "用户主动提交反馈", "服务端（用于回复与排查）", "是（用户主动提交）"],
        ["头像、导出文件", "用户选择 / 主动导出", "手机本地", "否"],
    ], widths=[2200, 2000, 2000, 3500], size=9, head_size=9)

    h3(doc, "14.2　本地存储与清除")
    body(doc, "课表、成绩、个人资料与登录凭据保存在应用私有目录，其它应用无法读取。用户可通过"
              "「账号与安全 → 清除本地课表」「退出登录并清除账号」「更多 → 隐私协议撤回」三种方式清除，"
              "其中撤回同意会删除本机全部个人信息并回到未登录状态。", before=3)

    h3(doc, "14.3　服务端的作用范围")
    body(doc, "服务端只承担两件事：①暂存用户主动分享的课表口令（30 天自动失效，不含任何身份信息）；"
              "②接收用户主动提交的反馈（文字、图片、联系方式）。开发者不采集通讯录、位置、设备标识、"
              "使用行为等任何其它数据，未集成广告、统计、推送、崩溃上报等第三方 SDK。", before=3)

    h3(doc, "14.4　已知待修正项（如实说明）")
    body(doc, "以下两项为当前版本已知问题，已列入下个版本的修正计划：", before=3)
    para(doc, "", after=1)
    bullet(doc, "分享与反馈接口目前使用 http 明文传输，下个版本改为 https。")
    bullet(doc, "应用内「关于」与隐私说明中个别表述（如「不上传任何个人信息」「不运营任何服务器」）"
                "未覆盖「口令分享」与「反馈」两处主动上传场景，下个版本改为准确描述。")

    # ------------------------------------------------------------------ 15
    h1(doc, "15　审核提示")
    h3(doc, "15.1　如果需要登录才能核对的功能")
    para(doc, "", after=1)
    bullet(doc, "学校教务系统只对校内网络开放，请在学校网络环境下登录；校外网络下该功能不可用，"
                "属学校限制，不是应用缺陷。")
    bullet(doc, "账号为学校分配的学号与教务密码，涉及在校学生的成绩与身份信息，因此不提供测试账号；"
                "也请勿使用他人账号登录。")
    bullet(doc, "不登录即可核对绝大部分界面：手动添加课程、校历、上课提醒、外观设置，以及用"
                "2.2 的示例口令导入的完整课表。")
    bullet(doc, "如提示网络异常，「我的 → 网络检测」可区分教务系统不可达与本机网络问题；教务系统偶有"
                "维护窗口，维护期间任何客户端都无法登录，稍后重试即可。")

    h3(doc, "15.2　与「校园网限制」有关的说明")
    body(doc, "教务系统仅校内开放，应用本身不做任何网络限制；应用内「常见问题」也如实写明需在校内网络"
              "登录。审核可在无账号状态下核对课表渲染（示例口令）、校历、提醒与全部设置项，"
              "不受此限制影响。", before=3)

    h3(doc, "15.3　成绩与绩点的计算口径")
    body(doc, "加权平均分、平均绩点由应用按学校公开的学分与绩点对应关系在本地计算，用于快速查看学习"
              "情况；如与教务系统显示存在差异，以教务系统为准。应用不对成绩做任何修改或回写。", before=3)

    h3(doc, "15.4　与学校的关系")
    body(doc, "本应用由个人开发者独立开发，与福州外语外贸学院无隶属或合作关系，非学校官方应用；"
              "所有课表、成绩数据均来自用户本人登录学校教务系统后同步的结果，应用内「关于」页已注明。",
         before=3)

    h3(doc, "15.5　联系方式")
    body(doc, "开发者：李立翔　　邮箱：lilixiang2762@gmail.com", before=3)
    body(doc, "如需补充材料（录屏、接口说明等）或有任何疑问，可通过上述邮箱联系，承诺 2 个工作日内回复。")

    doc.save(str(OUT))
    print("saved", OUT, OUT.stat().st_size)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main()









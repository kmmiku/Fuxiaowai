# 删除 docx 包内未被正文引用的图片，并同步剔除对应的 rels 条目
import io
import re
import shutil
import sys
import zipfile

SRC = sys.argv[1]
DST = sys.argv[2]

zin = zipfile.ZipFile(SRC)
doc_xml = zin.read("word/document.xml").decode("utf-8")
rels_xml = zin.read("word/_rels/document.xml.rels").decode("utf-8")

used_ids = set(re.findall(r'r:(?:embed|link|id)="([^"]+)"', doc_xml))
rel_re = re.compile(r'<Relationship\b[^>]*/>')
rels = rel_re.findall(rels_xml)
keep_rels, drop_targets = [], set()
for rel in rels:
    rid = re.search(r'Id="([^"]+)"', rel).group(1)
    target = re.search(r'Target="([^"]+)"', rel).group(1)
    if target.startswith("media/") and rid not in used_ids:
        drop_targets.add("word/" + target)
        continue
    keep_rels.append(rel)

new_rels = re.sub(
    r'(<Relationships\b[^>]*>).*?(</Relationships>)',
    lambda m: m.group(1) + "".join(keep_rels) + m.group(2),
    rels_xml,
    flags=re.S,
)

kept = dropped = 0
with zipfile.ZipFile(DST, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        name = item.filename
        if name in drop_targets:
            dropped += 1
            continue
        if name == "word/_rels/document.xml.rels":
            zout.writestr(item, new_rels.encode("utf-8"))
            continue
        zout.writestr(item, zin.read(name))
        if name.startswith("word/media/"):
            kept += 1
zin.close()
print("kept media", kept, "dropped", dropped, "out", DST)
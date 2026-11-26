#!/usr/bin/env python3
"""Đóng gói mọi plugin SketchUp trong kho BoToolSketchUp.
Chạy ở thư mục gốc kho:  python3 dong_goi.py [thư_mục_ra]   (mặc định /mnt/project-files)
Mỗi plugin là 1 thư mục cấp 1 có MaNguon/ (file .rb nạp + thư mục code), HuongDan.txt.
Với mỗi plugin <Ten>: tạo <Ten>/capnhat.json (plugin đọc để tự cập nhật), <Ten>/<Ten>.rbz,
và <thư_mục_ra>/<Ten>_SketchUp.zip (rbz + HuongDan.txt).
Ghi chú cập nhật lấy từ CHANGELOG.md, dòng dạng:  - <Ten> v<phiên bản>: <thay đổi>"""
import json, os, re, sys, zipfile
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files'

news, date = [], ''
for line in open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8'):
    m = re.match(r'##\s*(\d{4}-\d{2}-\d{2})', line)
    if m: date = m.group(1); continue
    if line.startswith('- ') and date: news.append((date, line[2:].strip()))

def note_for(prefix, version):
    for d, txt in news:
        m = re.match(re.escape(prefix) + r'\s+v' + re.escape(version) + r'\s*:\s*(.+)', txt)
        if m: n = m.group(1); return n[:1].upper() + n[1:]
    return ''

for name in sorted(os.listdir(ROOT)):
    base = os.path.join(ROOT, name)
    src = os.path.join(base, 'MaNguon')
    if not os.path.isdir(src): continue
    files = sorted(os.path.relpath(os.path.join(dp, f), src).replace(os.sep, '/') for dp, _, fs in os.walk(src) for f in fs)
    loader = [f for f in files if '/' not in f and f.endswith('.rb')]
    assert len(loader) == 1, 'Cần đúng 1 file .rb nạp trong ' + src
    t = open(os.path.join(src, loader[0]), encoding='utf-8').read()
    v = re.search(r"VERSION = '([^']+)'", t).group(1)
    d = re.search(r"DATE = '([^']+)'", t).group(1)
    note = note_for(name, v)
    assert note, 'CHANGELOG.md thiếu dòng "- %s v%s: ..."' % (name, v)
    json.dump({'version': v, 'date': d, 'notes': note, 'files': files},
              open(os.path.join(base, 'capnhat.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    rbz = os.path.join(base, name + '.rbz')
    with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as zf:
        for f in files: zf.write(os.path.join(src, f), f)
    z = os.path.join(OUT, name + '_SketchUp.zip')
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.write(rbz, name + '_SketchUp/' + name + '.rbz')
        zf.write(os.path.join(base, 'HuongDan.txt'), name + '_SketchUp/HuongDan.txt')
    print('OK', name, v, z)

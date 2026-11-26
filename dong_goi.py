#!/usr/bin/env python3
"""Đóng gói Bộ Tool SketchUp.
Chạy ở thư mục gốc kho:  python3 dong_goi.py [thư_mục_ra]   (mặc định /mnt/project-files)
- Đọc @version/@date của bảng (MaNguon/phuc_botool/launcher.rb) và của từng tool (MaNguon/phuc_botool/tools/<Id>/main.rb).
- Ghi chú lấy từ CHANGELOG.md, dòng dạng:  - Bộ Tool SketchUp v1.0.0: ...   hoặc   - <Id> v1.3.0: ...
- Tạo capnhat.json (nút Cập nhật trong bảng đọc file này), BoToolSketchUp.rbz và <thư_mục_ra>/BoToolSketchUp.zip."""
import json, os, re, sys, zipfile
ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'MaNguon')
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
    raise SystemExit('CHANGELOG.md thiếu dòng "- %s v%s: ..."' % (prefix, version))

def header(path):
    t = open(path, encoding='utf-8').read(3000)
    h = {}
    for k, v in re.findall(r'@(\w+):[ \t]*([^\r\n]+)', t): h.setdefault(k, v.strip())
    return h

lh = header(os.path.join(SRC, 'phuc_botool', 'launcher.rb'))
tools = []
tdir = os.path.join(SRC, 'phuc_botool', 'tools')
for tid in sorted(os.listdir(tdir)):
    f = os.path.join(tdir, tid, 'main.rb')
    if not os.path.isfile(f): continue
    h = header(f)
    for k in ('name', 'group', 'desc', 'version', 'date', 'module'):
        assert h.get(k), 'Thiếu @%s trong %s' % (k, f)
    tools.append({'id': tid, 'name': h['name'], 'version': h['version'], 'date': h['date'], 'notes': note_for(tid, h['version'])})
files = sorted(os.path.relpath(os.path.join(dp, f), SRC).replace(os.sep, '/') for dp, _, fs in os.walk(SRC) for f in fs)
info = {'version': lh['version'], 'date': lh['date'], 'notes': note_for('Bộ Tool SketchUp', lh['version']),
        'tools': tools, 'files': files, 'news': [{'date': d, 'text': t} for d, t in news[:10]]}
json.dump(info, open(os.path.join(ROOT, 'capnhat.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

rbz = os.path.join(ROOT, 'BoToolSketchUp.rbz')
with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as zf:
    for f in files: zf.write(os.path.join(SRC, f), f)
z = os.path.join(OUT, 'BoToolSketchUp.zip')
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.write(rbz, 'BoToolSketchUp/BoToolSketchUp.rbz')
    zf.write(os.path.join(ROOT, 'HuongDan.txt'), 'BoToolSketchUp/HuongDan.txt')
print('OK bảng', lh['version'], [(t['id'], t['version']) for t in tools], z)

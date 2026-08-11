import argparse
import collections
import json
import os
import plistlib
import re
import struct
import zipfile

TERMS = [
    'camera','record','shutter','iso','white balance','tint','fps','frame','resolution','codec',
    'apple prores','braw','lut','focus','false','zebra','histogram','storage','audio','timecode',
    'slate','cloud','chat','project','upload','settings','display','guide','grid','anamorphic',
    'stabil','lens','exposure','iris','wb','angle','off speed','quality','proxy','clip','remote',
    'monitor','meter','battery','media','blackmagic','davinci','safe area','color space',
    'dynamic range','focus assist','peak','zoom','aperture','nd','look','preset','duration',
    'trigger','scene','take','reel','roll','metadata','gyro','tilt','overlay','clean feed',
    'icon','ae','af','awb','hdmi','bmdcloud','grids','control','play','lock'
]

def keep(s):
    if not s or len(s) < 2:
        return False
    low = s.lower()
    return any(t in low for t in TERMS)

def asset_ui_keep(name):
    low = name.lower()
    if any(x in low for x in ('renditions', 'metadata', 'coreui', 'coretheme')):
        return False
    terms = (
        'appicon', 'apple watch', 'autoae', 'autoaf', 'autolock', 'battery', 'bmdcloud',
        'camera', 'cloud', 'control', 'exposure', 'false', 'focus', 'grids', 'guides',
        'hdmi', 'hud', 'icon', 'lock', 'lut', 'media', 'project', 'receiving', 'record',
        'remote', 'slate', 'sort', 'storage', 'sync', 'timelapse', 'upload', 'wb', 'zebra'
    )
    return any(term in low for term in terms)

def ascii_strings(data):
    return [m.group().decode('utf-8', 'ignore') for m in re.finditer(rb'[\x20-\x7e]{4,}', data)]

def utf16le_strings(data):
    out = []
    for m in re.finditer(rb'(?:[\x20-\x7e]\x00){4,}', data):
        try:
            out.append(m.group().decode('utf-16le', 'ignore'))
        except Exception:
            pass
    return out

def parse_macho_slice(full):
    if len(full) < 32:
        return {'error': 'slice short'}
    magic_le = struct.unpack_from('<I', full, 0)[0]
    endian = '<' if magic_le in (0xfeedface, 0xfeedfacf) else '>'
    magic = struct.unpack_from(endian + 'I', full, 0)[0]
    is64 = magic in (0xfeedfacf, 0xcffaedfe)
    if is64:
        hdr = struct.unpack_from(endian + 'IiiIIIII', full, 0)
        _, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, _ = hdr
        header_size = 32
    else:
        hdr = struct.unpack_from(endian + 'IiiIIII', full, 0)
        _, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = hdr
        header_size = 28
    res = {
        'magic': hex(magic), 'is64': is64, 'cputype': cputype, 'cpusubtype': cpusubtype,
        'filetype': filetype, 'ncmds': ncmds, 'sizeofcmds': sizeofcmds, 'flags': hex(flags),
        'encryption': [], 'dylibs_sample': []
    }
    off = header_size
    dylibs = []
    for _i in range(min(ncmds, 400)):
        if off + 8 > len(full):
            break
        cmd, cmdsize = struct.unpack_from(endian + 'II', full, off)
        if cmd in (0x21, 0x2C) and off + 20 <= len(full):
            cryptoff, cryptsize, cryptid = struct.unpack_from(endian + 'III', full, off + 8)
            res['encryption'].append({'cmd': hex(cmd), 'cryptoff': cryptoff, 'cryptsize': cryptsize, 'cryptid': cryptid})
        if cmd in (0xc, 0xd, 0x80000018) and off + 24 <= len(full):
            name_off = struct.unpack_from(endian + 'I', full, off + 8)[0]
            start = off + name_off
            end = off + cmdsize
            if start < end <= len(full):
                raw = full[start:end].split(b'\0', 1)[0]
                dylibs.append(raw.decode('utf-8', 'ignore'))
        off += cmdsize if cmdsize else 8
    res['dylibs_sample'] = dylibs[:160]
    return res

def parse_macho(path):
    with open(path, 'rb') as f:
        full_head = f.read(262144)
    if len(full_head) < 8:
        return {'error': 'short'}
    be_magic = struct.unpack_from('>I', full_head, 0)[0]
    if be_magic in (0xcafebabe, 0xcafebabf):
        with open(path, 'rb') as f:
            full = f.read()
        nfat = struct.unpack_from('>I', full, 4)[0]
        res = {'fat': True, 'nfat': nfat, 'slices': []}
        off = 8
        for _i in range(nfat):
            if be_magic == 0xcafebabf:
                cputype, cpusub, offset, size, align, reserved = struct.unpack_from('>IIQQII', full, off)
                off += 32
            else:
                cputype, cpusub, offset, size, align = struct.unpack_from('>IIIII', full, off)
                off += 20
            res['slices'].append({'cputype': cputype, 'cpusubtype': cpusub, 'offset': offset, 'size': size,
                                  'analysis': parse_macho_slice(full[offset:offset + min(size, 262144)])})
        return res
    return {'fat': False, **parse_macho_slice(full_head)}


def decode_text_resource(path):
    data = open(path, 'rb').read()
    for enc in ('utf-16-le', 'utf-16', 'utf-8-sig', 'utf-8', 'latin1'):
        try:
            text = data.decode(enc)
            if text.count('\x00') < max(1, len(text) // 20):
                return text
        except Exception:
            continue
    return data.decode('latin1', 'ignore')

def parse_strings_pairs(path):
    text = decode_text_resource(path)
    pairs = {}
    pattern = re.compile(r'"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', re.S)
    for key, value in pattern.findall(text):
        unesc = lambda x: x.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
        pairs[unesc(key)] = unesc(value)
    return pairs

def extract_settings_comment_hierarchy(path):
    text = decode_text_resource(path)
    blocks = re.findall(r'/\*(.*?)\*/\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', text, flags=re.S)
    rows = []
    hierarchy = collections.defaultdict(lambda: collections.defaultdict(set))
    for comment, key, value in blocks:
        for line in comment.splitlines():
            line = line.strip(' *')
            if not line.startswith('Settings >'):
                continue
            parts = [x.strip() for x in line.split('>')]
            if len(parts) < 3:
                continue
            category, item = parts[1], parts[2]
            subpath = ' > '.join(parts[3:]) if len(parts) > 3 else ''
            hierarchy[category][item].add(subpath)
            rows.append({'category': category, 'item': item, 'subpath': subpath, 'key': key, 'value': value, 'comment': line})
    serial = {
        category: {item: sorted(x for x in subpaths if x) for item, subpaths in sorted(items.items())}
        for category, items in sorted(hierarchy.items())
    }
    return serial, rows

def extract_assets_car_names(app, resources):
    result = {}
    pattern = re.compile(rb'[A-Za-z0-9_@./+\- ]{3,120}')
    for rel, _size, ext in resources:
        if os.path.basename(rel) != 'Assets.car':
            continue
        p = os.path.join(app, rel)
        try:
            data = open(p, 'rb').read()
        except Exception:
            continue
        names = []
        used = set()
        for match in pattern.finditer(data):
            name = match.group().decode('utf-8', 'ignore').strip('\x00 ')
            if not name or len(name) < 3:
                continue
            if any(x in name for x in ('@(#)PROGRAM', 'CoreUI', 'CoreTheme', 'Rendition', '/System/Library')):
                continue
            if not re.search(r'[A-Za-z]', name):
                continue
            if name not in used:
                used.add(name)
                names.append(name)
        result[rel] = names
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ipa', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    extract = os.path.join(args.out, 'ipa')
    os.makedirs(extract, exist_ok=True)
    with zipfile.ZipFile(args.ipa) as z:
        members = z.namelist()
        if not os.listdir(extract):
            z.extractall(extract)
    app_root = os.path.join(extract, 'Payload')
    app_dirs = [os.path.join(app_root, d) for d in os.listdir(app_root) if d.endswith('.app')]
    if not app_dirs:
        raise SystemExit('no .app under Payload')
    app = app_dirs[0]
    info_path = os.path.join(app, 'Info.plist')
    with open(info_path, 'rb') as f:
        info = plistlib.load(f)
    exe_name = info.get('CFBundleExecutable') or info.get('CFBundleName')
    exe_path = os.path.join(app, exe_name)
    resources = []
    ext_counts = collections.Counter()
    for dp, _dns, fns in os.walk(app):
        for fn in fns:
            p = os.path.join(dp, fn)
            rel = os.path.relpath(p, app)
            ext = os.path.splitext(fn)[1].lower() or '<noext>'
            size = os.path.getsize(p)
            resources.append((rel, size, ext))
            ext_counts[ext] += 1
    selected_exts = {'.strings','.plist','.storyboardc','.nib','.car','.json','.txt','.metallib','.momd','.mom','.loctable','.stringsdict'}
    all_strings = []
    for rel, size, ext in resources:
        if ext in selected_exts or 'lproj' in rel.lower() or ext == '<noext>':
            p = os.path.join(app, rel)
            try:
                data = open(p, 'rb').read()
            except Exception:
                continue
            for s in ascii_strings(data) + utf16le_strings(data):
                st = ' '.join(s.split())
                if 2 <= len(st) <= 220:
                    all_strings.append((rel, st))
    if os.path.exists(exe_path):
        data = open(exe_path, 'rb').read()
        for s in ascii_strings(data) + utf16le_strings(data):
            st = ' '.join(s.split())
            if 2 <= len(st) <= 220:
                all_strings.append((os.path.basename(exe_path), st))
    ui_strings = []
    seen = set()
    for rel, st in all_strings:
        if keep(st):
            key = (rel, st)
            if key not in seen:
                seen.add(key)
                ui_strings.append({'file': rel, 'string': st})
    file_terms = [{'file': rel, 'size': size} for rel, size, _ext in resources if keep(rel.replace('_', ' ').replace('-', ' '))]
    summary = {
        'ipa': args.ipa,
        'app': app,
        'member_count': len(members),
        'info': {k: info.get(k) for k in sorted(info.keys()) if k.startswith('CFBundle') or k.startswith('UI') or k in ('MinimumOSVersion','DTPlatformVersion')},
        'executable': exe_path if os.path.exists(exe_path) else None,
        'macho': parse_macho(exe_path) if os.path.exists(exe_path) else {'exists': False},
        'extension_counts': ext_counts.most_common(120),
        'largest_files': sorted([(rel, size) for rel, size, _ext in resources], key=lambda x: x[1], reverse=True)[:120],
        'ui_string_count': len(ui_strings),
        'ui_file_term_count': len(file_terms),
    }
    with open(os.path.join(args.out, 'ipa_summary.json'), 'w', encoding='utf-8') as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    with open(os.path.join(args.out, 'ui_strings.json'), 'w', encoding='utf-8') as f:
        json.dump(ui_strings, f, ensure_ascii=False, indent=2)
    with open(os.path.join(args.out, 'ui_file_terms.json'), 'w', encoding='utf-8') as f:
        json.dump(file_terms, f, ensure_ascii=False, indent=2)
    with open(os.path.join(args.out, 'ui_strings.txt'), 'w', encoding='utf-8') as f:
        for x in ui_strings:
            f.write(f"{x['file']}\t{x['string']}\n")
    with open(os.path.join(args.out, 'resource_inventory.tsv'), 'w', encoding='utf-8') as f:
        f.write('relpath\tsize\text\n')
        for rel, size, ext in sorted(resources):
            f.write(f'{rel}\t{size}\t{ext}\n')

    localized_strings = {}
    settings_hierarchy = {}
    settings_rows = []
    for rel, _size, ext in resources:
        if ext != '.strings':
            continue
        p = os.path.join(app, rel)
        try:
            pairs = parse_strings_pairs(p)
        except Exception as e:
            pairs = {'__parse_error__': str(e)}
        localized_strings[rel] = pairs
        rel_norm = rel.replace(os.sep, '/')
        if rel_norm.endswith('CameraAppToolbox.framework/en.lproj/Localizable.strings') or rel_norm.endswith('en.lproj/Localizable.strings'):
            try:
                settings_hierarchy, settings_rows = extract_settings_comment_hierarchy(p)
            except Exception as e:
                settings_hierarchy, settings_rows = {'__parse_error__': str(e)}, []
    with open(os.path.join(args.out, 'localized_strings.json'), 'w', encoding='utf-8') as f:
        json.dump(localized_strings, f, ensure_ascii=False, indent=2)
    with open(os.path.join(args.out, 'settings_comment_hierarchy.json'), 'w', encoding='utf-8') as f:
        json.dump(settings_hierarchy, f, ensure_ascii=False, indent=2)
    with open(os.path.join(args.out, 'settings_comment_rows.json'), 'w', encoding='utf-8') as f:
        json.dump(settings_rows, f, ensure_ascii=False, indent=2)

    asset_names = extract_assets_car_names(app, resources)
    with open(os.path.join(args.out, 'assets_car_strings.json'), 'w', encoding='utf-8') as f:
        json.dump(asset_names, f, ensure_ascii=False, indent=2)
    with open(os.path.join(args.out, 'assets_car_ui_names.txt'), 'w', encoding='utf-8') as f:
        for rel, names in asset_names.items():
            for name in names:
                if rel == 'Assets.car' and not name.lower().startswith('appicon'):
                    continue
                if asset_ui_keep(name):
                    f.write(f'{rel}\t{name}\n')
    print(json.dumps({
        'out': args.out,
        'app': app,
        'exe': exe_path,
        'ui_strings': len(ui_strings),
        'file_terms': len(file_terms),
        'assets_car_files': len(asset_names),
        'settings_rows': len(settings_rows),
        'macho': summary['macho'],
        'largest': summary['largest_files'][:12],
    }, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()


import argparse
import collections
import hashlib
import json
import os
import plistlib
import re
import zipfile
from pathlib import Path

UI_BUCKETS = {
    "main_pages": ["MainUIView", "pageCamera", "pageMedia", "pageChat", "pageSettings", "BmdPagingView", "BmdPageControl"],
    "camera_hud": ["HUDCameraControls", "HUDTopLeftIndicators", "HUDTopIndicators", "HUDTrailingIndicators", "HUDLeadingIndicators", "RecordTimerTextIndicator", "RecordButton", "HUDTallyIndicator", "HUDTimelapseIndicator"],
    "footer_controls": ["LHUDFooterElements", "PHUDFooterElements", "PLHUDFooterElements", "BmdAdjustmentDial", "BmdAdjustmentDialMarker", "BmdDialHDivider", "BmdDialVDivider", "LensOptions", "FpsOptions", "ShutterScroll", "IrisScroll", "IsoScroll", "WhiteBalanceScroll", "TintScroll"],
    "monitor_overlays": ["HUDGuides", "HUDSafeAreas", "HUDWhiteBalanceOverlay", "HUDFalseColor", "ImageHistogram", "AudioMeter", "StorageStatusHUD", "UploadStatusHUD", "FalseColor", "FocusAssist", "Zebra", "Clean Feed"],
    "settings_media_chat": ["SettingsCategoryPanel", "SettingsOptionsPanel", "OptionListView", "MediaViewSidebar", "MediaViewToolbar", "MediaSortPanel", "MediaUploadToCloudPanel", "MediaClipDetailsLandscapePanel", "ChatViewSidebar", "ChatTableView", "CloudLoginView", "SlateViewProjectInfo", "SlateViewClipInfo", "SlateViewLensInfo"],
    "layout_metrics": ["MainViewLayoutData", "pageTabWidth", "pageTabHeight", "footerHeight", "hudControlsHeight", "navMenuEdgePadding", "leftNavMenuSwipeWidthArea", "rightNavMenuSwipeWidthArea", "recordBarSpacing", "getPageTabWidthForLandscapeMode"],
    "appintents": ["StartRecordIntent", "StopRecordIntent", "OpenCameraView", "SetLensIntent", "SetFrameRateIntent", "SetShutterSpeedIntent", "SetISOIntent", "SetWhiteBalanceIntent", "TintIntent", "ExposureIntent", "FocusIntent", "ZoomIntent", "StabilizationIntent", "CodecIntent", "SetResolutionIntent", "SetProjectIntent"],
}

ASSET_TERMS = [
    "Camera", "Media", "Cloud", "ControlIcon", "Record", "Slate", "Exposure", "Focus", "FalseColor", "Guides", "Grids", "Zebra", "Lut", "BatteryIndicator", "Storage", "Upload", "Sync", "Stream", "Hdmi", "IconAf", "IconAwb", "IconLock", "IconLut", "IconTimelapse", "Sort"
]

SETTING_COMMENT_RE = re.compile(r'/\*(.*?)\*/\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', re.S)
STRING_PAIR_RE = re.compile(r'"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', re.S)
ASCII_RE = re.compile(rb'[\x20-\x7e]{4,}')
UTF16_RE = re.compile(rb'(?:[\x20-\x7e]\x00){4,}')


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def extract_ipa(ipa: Path, out: Path) -> Path:
    extract = out / 'extract'
    payload = extract / 'Payload'
    if not payload.exists():
        with zipfile.ZipFile(ipa) as z:
            z.extractall(extract)
    apps = list(payload.glob('*.app'))
    if not apps:
        raise SystemExit('No .app found under Payload')
    return apps[0]


def decode_text(data: bytes) -> str:
    for enc in ('utf-16-le', 'utf-16', 'utf-8-sig', 'utf-8', 'latin1'):
        try:
            text = data.decode(enc)
            if text.count('\x00') < max(1, len(text) // 20):
                return text
        except Exception:
            pass
    return data.decode('latin1', 'ignore')


def unesc(s: str) -> str:
    return s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')


def strings_from_bytes(data: bytes):
    out = []
    for m in ASCII_RE.finditer(data):
        out.append(m.group().decode('utf-8', 'ignore'))
    for m in UTF16_RE.finditer(data):
        out.append(m.group().decode('utf-16-le', 'ignore'))
    return out


def focused_strings(path: Path):
    try:
        data = path.read_bytes()
    except Exception:
        return []
    rows = []
    for s in strings_from_bytes(data):
        st = ' '.join(s.split())
        if not (3 <= len(st) <= 220):
            continue
        for bucket, terms in UI_BUCKETS.items():
            if any(term.lower() in st.lower() for term in terms):
                rows.append({"bucket": bucket, "file": str(path.name), "string": st})
                break
    seen, uniq = set(), []
    for row in rows:
        key = (row['bucket'], row['file'], row['string'])
        if key not in seen:
            seen.add(key); uniq.append(row)
    return uniq


def parse_localizable(path: Path):
    data = path.read_bytes()
    text = decode_text(data)
    pairs = {unesc(k): unesc(v) for k, v in STRING_PAIR_RE.findall(text)}
    hierarchy = collections.defaultdict(lambda: collections.defaultdict(set))
    rows = []
    for comment, key, value in SETTING_COMMENT_RE.findall(text):
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
            rows.append({"category": category, "item": item, "subpath": subpath, "key": unesc(key), "value": unesc(value)})
    serial = {cat: {item: sorted(x for x in subs if x) for item, subs in sorted(items.items())} for cat, items in sorted(hierarchy.items())}
    return pairs, serial, rows


def collect_assets(app: Path):
    names = set()
    for car in app.rglob('Assets.car'):
        data = car.read_bytes()
        for m in re.finditer(rb'[A-Za-z0-9_@./+\- ]{3,120}', data):
            name = m.group().decode('utf-8', 'ignore').strip('\x00 ')
            if not name or 'CoreUI' in name or 'Rendition' in name or '/System/' in name:
                continue
            if any(term.lower() in name.lower() for term in ASSET_TERMS):
                names.add(name)
    return sorted(names, key=lambda x: x.lower())


def summarize_appintents(app: Path):
    rows = []
    d = app / 'Metadata.appintents'
    if not d.exists():
        return rows
    raw = '\n'.join(' '.join(s.split()) for f in d.rglob('*') if f.is_file() for s in strings_from_bytes(f.read_bytes()))
    for term in UI_BUCKETS['appintents']:
        if term in raw:
            fmt = ''
            m = re.search(rf'({re.escape(term)}.*?)(Set |Start |Stop |Navigate |$)', raw)
            if m:
                fmt = m.group(1)[:220]
            rows.append({"intent": term, "evidence": fmt})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ipa', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args()
    ipa = Path(args.ipa)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    app = extract_ipa(ipa, out)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    exe = app / info.get('CFBundleExecutable', 'BlackmagicCam')
    toolbox = app / 'Frameworks' / 'CameraAppToolbox.framework' / 'CameraAppToolbox'
    localized = app / 'Frameworks' / 'CameraAppToolbox.framework' / 'en.lproj' / 'Localizable.strings'
    pairs, settings_hierarchy, settings_rows = parse_localizable(localized)
    assets = collect_assets(app)
    focused = []
    for p in [exe, toolbox]:
        if p.exists():
            focused.extend(focused_strings(p))
    intents = summarize_appintents(app)
    inventory = []
    for p in app.rglob('*'):
        if p.is_file():
            inventory.append({"path": str(p.relative_to(app)), "size": p.stat().st_size, "ext": p.suffix.lower() or '<none>'})
    inventory.sort(key=lambda x: x['size'], reverse=True)
    buckets = collections.defaultdict(list)
    for row in focused:
        if len(buckets[row['bucket']]) < 80:
            buckets[row['bucket']].append(row['string'])
    facts = {
        "source_ipa": str(ipa),
        "sha256": sha256(ipa),
        "bundle": info.get('CFBundleIdentifier'),
        "version": info.get('CFBundleShortVersionString'),
        "build": info.get('CFBundleVersion'),
        "minimum_os": info.get('MinimumOSVersion'),
        "orientations": info.get('UISupportedInterfaceOrientations'),
        "fonts": info.get('UIAppFonts', []),
        "resource_counts": collections.Counter(x['ext'] for x in inventory),
        "largest_files": inventory[:30],
        "settings_hierarchy": settings_hierarchy,
        "settings_rows_sample": settings_rows[:200],
        "asset_names": assets,
        "appintents": intents,
        "focused_symbol_buckets": buckets,
        "requirements": [
            "Full-screen monitor-first camera page; no app title banner over preview.",
            "Landscape camera page uses a right-edge pageCamera/pageMedia/pageChat/pageSettings BmdVTabView rail.",
            "Portrait camera page uses a bottom pageCamera/pageMedia/pageChat/pageSettings BmdTabView rail with compact labels.",
            "Monitor/control tools are icon-only chrome: a right utility strip in landscape and a bottom control dock in portrait.",
            "Camera readouts are exactly LENS, FPS, SHUTTER, IRIS, ISO, WB, TINT in the official order.",
            "Top overlay is compact project/timecode/status/readout, using BMD Lato fonts.",
            "Guides, false color, focus assist, zebra and white-balance overlays are tool-activated, not always-on default chrome.",
            "Settings uses a left SettingsCategoryPanel and a centered-title SettingsOptionsPanel with dense right-aligned rows.",
            "Media uses a compact MediaViewSidebar, icon-only MediaViewToolbar, dense thumbnail grid, and optional right contextual panel only when a media tool is selected.",
            "Chat uses a project/member ChatViewSidebar, compact participant-dot ChatViewToolbar, and dark ChatTableView message surface.",
            "Use recovered CameraAppToolbox Assets.car names and documented aliases before SF Symbol fallback.",
        ],
    }
    def json_default(o):
        if isinstance(o, collections.Counter): return dict(o)
        if isinstance(o, collections.defaultdict): return dict(o)
        return str(o)
    (out / 'complete_ui_facts.json').write_text(json.dumps(facts, ensure_ascii=False, indent=2, default=json_default), encoding='utf-8')
    md=[]
    md.append('# Blackmagic Cam 3.2.00 Complete UI Reverse Spec')
    md.append('')
    md.append(f"Source: `{ipa}`")
    md.append(f"SHA256: `{facts['sha256']}`")
    md.append(f"Bundle/version: `{facts['bundle']}` `{facts['version']} / {facts['build']}`")
    md.append('')
    md.append('## Hard Requirements')
    for req in facts['requirements']:
        md.append(f'- {req}')
    md.append('')
    md.append('## Evidence Buckets')
    for bucket in UI_BUCKETS:
        vals=buckets.get(bucket, [])
        if not vals: continue
        md.append(f'### {bucket}')
        for v in vals[:40]: md.append(f'- `{v}`')
        md.append('')
    md.append('## Settings Categories')
    for cat, items in settings_hierarchy.items():
        md.append(f'- **{cat}**: ' + ', '.join(list(items.keys())[:18]))
    md.append('')
    md.append('## AppIntents')
    for row in intents: md.append(f"- `{row['intent']}`")
    md.append('')
    md.append('## Asset Names')
    for name in assets[:180]: md.append(f'- `{name}`')
    md.append('')
    md.append('## Update Rule')
    md.append('When Blackmagic changes IPA/game-version-style UI, rerun this script against the new IPA, compare `complete_ui_facts.json`, then update `BlackmagicReverseSpec.swift` before view code.')
    (out / 'complete_ui_spec.md').write_text('\n'.join(md), encoding='utf-8')
    print(json.dumps({"out": str(out), "app": str(app), "focused_rows": len(focused), "asset_names": len(assets), "settings_rows": len(settings_rows), "intents": len(intents)}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'CamControlApp' / 'Sources'
DOC_SPEC = ROOT / 'docs' / 'blackmagic-cam-3.2.00-complete-ui-spec.md'
DOC_FACTS = ROOT / 'docs' / 'blackmagic-cam-3.2.00-complete-ui-facts.json'
ARTIFACT_FACTS = ROOT / 'artifacts' / 'blackmagic_complete_ui_3_2_00' / 'complete_ui_facts.json'
SPEC_JSON = DOC_FACTS if DOC_FACTS.exists() else ARTIFACT_FACTS

REQUIRED_HUD_LABELS = ["LENS", "FPS", "SHUTTER", "IRIS", "ISO", "WB", "TINT"]
FORBIDDEN_HUD_LABELS = ["Zoom", "Exposure", "Format", "STAB", "LUT"]
REQUIRED_SOURCE_PATTERNS = {
    'right_page_rail': (SRC / 'ShootingHUDComponents.swift', r'rightPageNavigationRail\(compact:'),
    'left_monitor_rail': (SRC / 'ShootingHUDComponents.swift', r'leftMonitorRail\(compact:'),
    'root_page_rail': (SRC / 'ShootingHUDComponents.swift', r'BlackmagicRootPageRail\(selection:'),
    'dial_scroller_options': (SRC / 'ShootingHUDComponents.swift', r'ScrollerOptionDial\('),
    'asset_aliases': (SRC / 'BMDAssetIcon.swift', r'Apple Watch/IconAf'),
    'chat_cloud_asset': (SRC / 'ShootingHUDComponents.swift', r'case \.chat: return "Cloud"'),
    'complete_reverse_script': (ROOT / 'scripts' / 'reverse_blackmagic_complete_ui.py', r'UI_BUCKETS'),
}
FORBIDDEN_SOURCE_PATTERNS = {
    'stale_left_app_nav': (SRC / 'ShootingHUDComponents.swift', r'leftQuickAccessRail|quickAccessButton|FloatingNavPill|trailingIndicators'),
    'bare_chat_asset_in_nav': (SRC / 'ShootingHUDComponents.swift', r'case \.chat: return "Chat"'),
}


def read(path: Path) -> str:
    if not path.exists():
        raise AssertionError(f'missing file: {path}')
    return path.read_text(encoding='utf-8', errors='ignore')


def check_spec():
    if not SPEC_JSON.exists():
        raise AssertionError(f'missing generated reverse facts: {SPEC_JSON}')
    facts = json.loads(read(SPEC_JSON))
    assert facts.get('source_ipa', '').endswith('Blackmagic Cam_3.2.00.ipa'), facts.get('source_ipa')
    assert facts.get('bundle') == 'com.blackmagic-design.DaVinciCamera', facts.get('bundle')
    assert facts.get('version') == '3.2.00', facts.get('version')
    assert len(facts.get('asset_names', [])) >= 400, len(facts.get('asset_names', []))
    assert len(facts.get('settings_rows_sample', [])) >= 100, len(facts.get('settings_rows_sample', []))
    assert len(facts.get('appintents', [])) >= 15, len(facts.get('appintents', []))
    assert DOC_SPEC.exists(), f'missing doc spec: {DOC_SPEC}'


def check_source_patterns():
    for name, (path, pattern) in REQUIRED_SOURCE_PATTERNS.items():
        txt = read(path)
        if not re.search(pattern, txt):
            raise AssertionError(f'missing required pattern {name}: {pattern} in {path}')
    for name, (path, pattern) in FORBIDDEN_SOURCE_PATTERNS.items():
        txt = read(path)
        if re.search(pattern, txt):
            raise AssertionError(f'forbidden stale pattern {name}: {pattern} in {path}')


def extract_top_item_labels(path: Path):
    txt = read(path)
    blocks = re.findall(r'private var topItems:\s*\[ShootingHUDTopItem\]\s*\{(.*?)\n\s*\}', txt, flags=re.S)
    labels = []
    for block in blocks:
        labels.extend(re.findall(r'ShootingHUDTopItem\(title:\s*"([^"]+)"', block))
    return labels


def check_hud_labels():
    for rel in ['PhoneCameraWorkspaceView.swift', 'LiveViewPanel.swift']:
        labels = extract_top_item_labels(SRC / rel)
        upper = [x.upper() for x in labels]
        if upper != REQUIRED_HUD_LABELS:
            raise AssertionError(f'{rel} HUD labels {labels} != {REQUIRED_HUD_LABELS}')
        for forbidden in FORBIDDEN_HUD_LABELS:
            if forbidden in labels:
                raise AssertionError(f'{rel} still exposes non-footer HUD label {forbidden}')


def check_asset_coverage():
    facts = json.loads(read(SPEC_JSON))
    assets = set(facts.get('asset_names', []))
    source = ''.join(read(p) for p in [SRC/'BlackmagicReverseSpec.swift', SRC/'BMDAssetIcon.swift', SRC/'ShootingHUDComponents.swift', SRC/'BlackmagicRootPageRail.swift'])
    names = set(re.findall(r'BMDAssetIcon\(name:\s*"([^"]+)"', source))
    names.update(re.findall(r'asset:\s*"([^"]+)"', source))
    names.update(re.findall(r'monitorIcon(?:Shell|Button)\(asset:\s*"([^"]+)"', source))
    aliases = {
        'IconAf': ['Apple Watch/IconAf', 'icon_AF'], 'IconAf_active': ['Apple Watch/IconAf_active', 'icon_AF_active'],
        'IconAwb': ['Apple Watch/IconAwb', 'icon_AWB'], 'IconAwb_active': ['Apple Watch/IconAwb_active', 'icon_AWB_active'],
        'IconLock': ['Apple Watch/IconLock', 'icon_lock', 'Lock', 'LockHud'], 'IconLock_active': ['Apple Watch/IconLock_active', 'icon_lock_active', 'Lock_active', 'LockHud_active'],
        'IconLut': ['Apple Watch/IconLut', 'icon_LUT', 'Lut'], 'IconLut_active': ['Apple Watch/IconLut_active', 'icon_LUT_active', 'Lut_active'],
        'IconTimelapse': ['Apple Watch/IconTimelapse', 'icon_timelapse', 'Timelapse'], 'IconTimelapse_active': ['Apple Watch/IconTimelapse_active', 'icon_timelapse_active'],
        'Chat': ['Cloud', 'BmdCloudSidebar'], 'Chat_active': ['Cloud', 'BmdCloudSidebar'], 'Lens': ['Camera', 'Camera_active'], 'Lens_active': ['Camera', 'Camera_active'],
    }
    missing = sorted(n for n in names if n not in assets and not any(a in assets for a in aliases.get(n, [])))
    if missing:
        raise AssertionError(f'asset names not covered by IPA assets/aliases: {missing}')


def main():
    checks = [check_spec, check_source_patterns, check_hud_labels, check_asset_coverage]
    for check in checks:
        check()
    print('blackmagic-ui-alignment: PASS')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'blackmagic-ui-alignment: FAIL: {exc}', file=sys.stderr)
        sys.exit(1)

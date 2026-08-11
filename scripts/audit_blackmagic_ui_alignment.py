import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'CamControlApp' / 'Sources'
DOC_SPEC = ROOT / 'docs' / 'blackmagic-cam-3.2.00-complete-ui-spec.md'
DOC_FACTS = ROOT / 'docs' / 'blackmagic-cam-3.2.00-complete-ui-facts.json'
ASSET_DIMENSIONS = ROOT / 'docs' / 'blackmagic-cam-3.2.00-asset-dimensions.tsv'
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
    'false_color_original_asset': (SRC / 'ShootingHUDComponents.swift', r'BMDAssetImage\(name: "FalseColorLegend".*preserveOriginalColors: true'),
    'bmd_cloud_logo_asset': (SRC / 'CloudChatPanel.swift', r'BMDAssetImage\(name: "BmdCloudLogo".*preserveOriginalColors: true'),
    'chat_participant_dots': (SRC / 'CloudChatPanel.swift', r'ChatParticipantDot\(initials: "MW"'),
    'chat_remote_camera_asset': (SRC / 'CloudChatPanel.swift', r'return "CameraLinkedSmall"'),
    'top_status_only_hud': (SRC / 'ShootingHUDComponents.swift', r'topLeftStatus\(compact: compact\)'),
    'footer_bmd_adjustment_dials': (SRC / 'ShootingHUDComponents.swift', r'BmdAdjustmentDialCell\(item: item, compact: compact, active: activeScroller == item\.scroller\)'),
    'footer_height_for_dials': (SRC / 'ShootingHUDComponents.swift', r'var footerHeight: CGFloat \{ compact \? 72 : 92 \}'),
    'icon_only_page_rail': (SRC / 'BlackmagicRootPageRail.swift', r'icon-only cells'),
    'liveview_live_asset_button': (SRC / 'LiveViewPanel.swift', r'stripLabel\("LIVE", asset: "HdmiPlay"'),
    'liveview_review_asset_button': (SRC / 'LiveViewPanel.swift', r'stripLabel\("REVIEW", asset: "IconTimelapse"'),
    'liveview_stream_asset_button': (SRC / 'LiveViewPanel.swift', r'stripLabel\("STREAM", asset: "IconStream"'),
    'slate_tab_panel': (SRC / 'ShootingHUDComponents.swift', r'SlateInfoTab|SlateViewProjectInfo|SlateViewClipInfo|SlateViewLensInfo'),
    'slate_close_asset': (SRC / 'ShootingHUDComponents.swift', r'BMDAssetIcon\(name: "SlateClose"'),
    'settings_option_list_cells': (SRC / 'PropertyPanel.swift', r'SettingsChoiceCell|OptionListView/BmdTextListSelector'),
    'chat_cloud_asset': (SRC / 'ShootingHUDComponents.swift', r'case \.chat: return "Cloud"'),
    'complete_reverse_script': (ROOT / 'scripts' / 'reverse_blackmagic_complete_ui.py', r'UI_BUCKETS'),
}
FORBIDDEN_SOURCE_PATTERNS = {
    'stale_left_app_nav': (SRC / 'ShootingHUDComponents.swift', r'leftQuickAccessRail|quickAccessButton|FloatingNavPill|trailingIndicators'),
    'bare_chat_asset_in_nav': (SRC / 'ShootingHUDComponents.swift', r'case \.chat: return "Chat"'),
    'top_footer_readout_duplication': (SRC / 'ShootingHUDComponents.swift', r'CameraTopReadout\(item:'),
    'mini_footer_not_bmd_dial': (SRC / 'ShootingHUDComponents.swift', r'MiniFooterReadout\(item:'),
    'visible_page_rail_text': (SRC / 'BlackmagicRootPageRail.swift', r'Text\(item\.title\.capitalized\)'),
    'liveview_sf_striplabel': (SRC / 'LiveViewPanel.swift', r'stripLabel\([^\\n]*systemImage:'),
    'chat_toolbar_sf_person_icons': (SRC / 'CloudChatPanel.swift', r'Image\(systemName:.*person\.crop\.circle'),
    'stale_camera_linked_asset': (SRC / 'CloudChatPanel.swift', r'return "CameraLinked"'),
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
    assert ASSET_DIMENSIONS.exists(), f'missing asset dimension evidence: {ASSET_DIMENSIONS}'
    dims = read(ASSET_DIMENSIONS)
    assert 'FalseColorLegend' in dims and '	150	603	' in dims, 'FalseColorLegend dimensions missing from assetutil evidence'
    assert 'BmdCloudLogo' in dims and '	853	276	' in dims, 'BmdCloudLogo dimensions missing from assetutil evidence'



def check_info_plist_parity():
    info_path = ROOT / 'CamControlApp' / 'Resources' / 'Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    assert info.get('CFBundleDisplayName') == 'Blackmagic Cam', info.get('CFBundleDisplayName')
    assert info.get('CFBundleName') == 'BlackmagicCam', info.get('CFBundleName')
    assert info.get('CFBundleShortVersionString') == '3.2.00', info.get('CFBundleShortVersionString')
    assert info.get('CFBundleVersion') == '3.2.000045', info.get('CFBundleVersion')
    assert info.get('LSApplicationCategoryType') == 'public.app-category.video', info.get('LSApplicationCategoryType')
    assert info.get('UIStatusBarHidden') is False, info.get('UIStatusBarHidden')
    assert info.get('UIViewControllerBasedStatusBarAppearance') is True, info.get('UIViewControllerBasedStatusBarAppearance')
    assert info.get('UIRequiresFullScreen') is True, info.get('UIRequiresFullScreen')
    assert info.get('UIFileSharingEnabled') is True, info.get('UIFileSharingEnabled')
    assert info.get('LSSupportsOpeningDocumentsInPlace') is True, info.get('LSSupportsOpeningDocumentsInPlace')
    assert info.get('NSCameraUsageDescription') == 'Access is required to preview and capture video.', info.get('NSCameraUsageDescription')
    assert info.get('NSMicrophoneUsageDescription') == 'Access is required to monitor audio levels and record.', info.get('NSMicrophoneUsageDescription')
    assert info.get('NSPhotoLibraryUsageDescription') == 'Access is required to save videos to the Photo Library.', info.get('NSPhotoLibraryUsageDescription')
    assert info.get('NSBluetoothAlwaysUsageDescription') == 'Bluetooth access is required to support peripherals.', info.get('NSBluetoothAlwaysUsageDescription')
    # Firmware/update note: these keys mirror F:\Blackmagic Cam_3.2.00.ipa Info.plist; rerun reverse_blackmagic_complete_ui.py before changing launch/status-bar behavior or permission UI text.

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
    source = ''.join(read(path) for path in SRC.glob('*.swift'))
    names = set(re.findall(r'BMDAsset(?:Icon|Image)\(name:\s*"([^"]+)"', source))
    names.update(re.findall(r'asset:\s*"([^"]+)"', source))
    names.update(re.findall(r'monitorIcon(?:Shell|Button)\(asset:\s*"([^"]+)"', source))
    aliases = {
        'IconAf': ['Apple Watch/IconAf', 'icon_AF'], 'IconAf_active': ['Apple Watch/IconAf_active', 'icon_AF_active'],
        'IconAwb': ['Apple Watch/IconAwb', 'icon_AWB'], 'IconAwb_active': ['Apple Watch/IconAwb_active', 'icon_AWB_active'],
        'IconLock': ['Apple Watch/IconLock', 'icon_lock', 'Lock', 'LockHud'], 'IconLock_active': ['Apple Watch/IconLock_active', 'icon_lock_active', 'Lock_active', 'LockHud_active'],
        'IconLut': ['Apple Watch/IconLut', 'icon_LUT', 'Lut'], 'IconLut_active': ['Apple Watch/IconLut_active', 'icon_LUT_active', 'Lut_active'],
        'IconStream': ['Apple Watch/IconStream', 'icon_stream'], 'IconStream_active': ['Apple Watch/IconStream_active', 'icon_stream_active'],
        'IconTimelapse': ['Apple Watch/IconTimelapse', 'icon_timelapse', 'Timelapse'], 'IconTimelapse_active': ['Apple Watch/IconTimelapse_active', 'icon_timelapse_active'],
        'Chat': ['Cloud', 'BmdCloudSidebar'], 'Chat_active': ['Cloud', 'BmdCloudSidebar'], 'Lens': ['Camera', 'Camera_active'], 'Lens_active': ['Camera', 'Camera_active'],
    }
    missing = sorted(n for n in names if n not in assets and not any(a in assets for a in aliases.get(n, [])))
    if missing:
        raise AssertionError(f'asset names not covered by IPA assets/aliases: {missing}')


def main():
    checks = [check_spec, check_info_plist_parity, check_source_patterns, check_hud_labels, check_asset_coverage]
    for check in checks:
        check()
    print('blackmagic-ui-alignment: PASS')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'blackmagic-ui-alignment: FAIL: {exc}', file=sys.stderr)
        sys.exit(1)

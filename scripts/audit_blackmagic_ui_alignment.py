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
    'official_top_readout_bar': (SRC / 'ShootingHUDComponents.swift', r'officialTopReadoutBar\(compact:'),
    'official_portrait_top_cluster': (SRC / 'ShootingHUDComponents.swift', r'officialPortraitTopCluster\(compact:'),
    'portrait_bottom_page_tab_bar': (SRC / 'ShootingHUDComponents.swift', r'rightPageNavigationRail\(compact: true, horizontal: true\)'),
    'left_monitor_rail': (SRC / 'ShootingHUDComponents.swift', r'leftMonitorRail\(compact:'),
    'root_page_rail': (SRC / 'ShootingHUDComponents.swift', r'BlackmagicRootPageRail\(selection:'),
    'dial_scroller_options': (SRC / 'ShootingHUDComponents.swift', r'ScrollerOptionDial\('),
    'asset_aliases': (SRC / 'BMDAssetIcon.swift', r'Apple Watch/IconAf'),
    'false_color_original_asset': (SRC / 'ShootingHUDComponents.swift', r'BMDAssetImage\(name: "FalseColorLegend".*preserveOriginalColors: true'),
    'bmd_cloud_logo_asset': (SRC / 'CloudChatPanel.swift', r'BMDAssetImage\(name: "BmdCloudLogo".*preserveOriginalColors: true'),
    'media_side_panel_rendered': (SRC / 'GalleryView.swift', r'mediaSidePanel\(compact: compact\)'),
    'media_side_panel_width': (SRC / 'GalleryView.swift', r'\.frame\(width: compact \? 190 : 280\)'),
    'media_fixture_grid': (SRC / 'GalleryView.swift', r'MediaFixtureClip\.samples'),
    'media_fixture_uses_real_crops': (SRC / 'GalleryView.swift', r'Image\(item\.imageName\)'),
    'chat_participant_dots': (SRC / 'CloudChatPanel.swift', r'ChatParticipantDot\(initials: "MW"'),
    'chat_project_sidebar': (SRC / 'CloudChatPanel.swift', r'CloudRoom\(title: "Short Film"[\s\S]*ProjectUploadFailed'),
    'cloud_chat_offline_badge': (SRC / 'CloudChatPanel.swift', r'OfflineCloudBadge\(compact: compact\)'),
    'cloud_chat_message_disabled': (SRC / 'CloudChatPanel.swift', r'Message disabled offline'),
    'media_upload_offline_stub': (SRC / 'GalleryView.swift', r'Cloud Transport", "Offline UI Only'),
    'top_status_only_hud': (SRC / 'ShootingHUDComponents.swift', r'topLeftStatus\(compact: compact\)'),
    'footer_bmd_adjustment_dials': (SRC / 'ShootingHUDComponents.swift', r'BmdAdjustmentDialCell\(item: item, compact: compact, active: activeScroller == item\.scroller\)'),
    'footer_height_for_dials': (SRC / 'ShootingHUDComponents.swift', r'var footerHeight: CGFloat \{ compact \? 72 : 92 \}'),
    'icon_only_page_rail': (SRC / 'BlackmagicRootPageRail.swift', r'landscape page tabs are icon-only'),
    'portrait_page_rail_labels': (SRC / 'BlackmagicRootPageRail.swift', r'Text\(item\.title\.capitalized\)'),
    'liveview_live_asset_button': (SRC / 'LiveViewPanel.swift', r'stripLabel\("LIVE", asset: "HdmiPlay"'),
    'liveview_review_asset_button': (SRC / 'LiveViewPanel.swift', r'stripLabel\("REVIEW", asset: "IconTimelapse"'),
    'liveview_stream_asset_button': (SRC / 'LiveViewPanel.swift', r'stripLabel\("STREAM", asset: "IconStream"'),
    'slate_tab_panel': (SRC / 'ShootingHUDComponents.swift', r'SlateInfoTab|SlateViewProjectInfo|SlateViewClipInfo|SlateViewLensInfo'),
    'slate_close_asset': (SRC / 'ShootingHUDComponents.swift', r'BMDAssetIcon\(name: "SlateClose"'),
    'settings_option_list_cells': (SRC / 'PropertyPanel.swift', r'SettingsChoiceCell|OptionListView/BmdTextListSelector'),
    'chat_cloud_asset': (SRC / 'ShootingHUDComponents.swift', r'case \.chat: return "Cloud"'),
    'nd_filter_scroller': (SRC / 'ShootingHUDComponents.swift', r'case \.ndFilter: return BlackmagicReverseSpec\.ndFilterOptions'),
    'nd_filter_options_spec': (SRC / 'BlackmagicReverseSpec.swift', r'static let ndFilterOptions'),
    'stream_timelapse_top_status': (SRC / 'ShootingHUDComponents.swift', r'TopHudGlyph\(asset: "IconStream"[\s\S]*TopHudGlyph\(asset: "IconTimelapse"'),
    'stabilisation_reverse_anchor': (SRC / 'BlackmagicReverseSpec.swift', r'StabilisationOptions'),
    'portrait_timecode_bar': (SRC / 'ShootingHUDComponents.swift', r'officialPortraitTopCluster\(compact: true\)'),
    'portrait_status_no_duplicate_timer': (SRC / 'ShootingHUDComponents.swift', r'portrait top cluster matches 3\.2\.00 screenshot'),
    'stealth_layout_toggle': (SRC / 'ShootingHUDComponents.swift', r'stealthHUD[\s\S]*StealthLayoutData'),
    'reset_settings_category': (SRC / 'BlackmagicReverseSpec.swift', r'static let resetChoices'),
    'reset_settings_panel_rows': (SRC / 'PropertyPanel.swift', r'valueForResetOption[\s\S]*Reset Settings Dialog'),
    'bmd_reversed_controls_file': (SRC / 'BlackmagicReversedControls.swift', r'BmdIndicatorIconButton[\s\S]*BmdTextButton[\s\S]*BmdPopoverShell[\s\S]*BmdTextListSelector'),
    'hud_camera_light_indicator': (SRC / 'ShootingHUDComponents.swift', r'HUDCameraLightIndicator\(title:'),
    'lut_names_panel_scroller': (SRC / 'ShootingHUDComponents.swift', r'LutNamesPanel\(compact:'),
    'audio_meter_mini': (SRC / 'ShootingHUDComponents.swift', r'AudioMeterMini\(levels:'),
    'complete_reverse_script': (ROOT / 'scripts' / 'reverse_blackmagic_complete_ui.py', r'UI_BUCKETS'),
    'phone_camera_lazy_session': (SRC / 'PhoneCameraWorkspaceView.swift', r'@Published private\(set\) var session: AVCaptureSession\?'),
}
FORBIDDEN_SOURCE_PATTERNS = {
    'stale_left_app_nav': (SRC / 'ShootingHUDComponents.swift', r'leftQuickAccessRail|quickAccessButton|FloatingNavPill|trailingIndicators'),
    'bare_chat_asset_in_nav': (SRC / 'ShootingHUDComponents.swift', r'case \.chat: return "Chat"'),
    'top_footer_readout_duplication': (SRC / 'ShootingHUDComponents.swift', r'CameraTopReadout\(item:'),
    'mini_footer_not_bmd_dial': (SRC / 'ShootingHUDComponents.swift', r'MiniFooterReadout\(item:'),
    'liveview_sf_striplabel': (SRC / 'LiveViewPanel.swift', r'stripLabel\([^\\n]*systemImage:'),
    'chat_toolbar_sf_person_icons': (SRC / 'CloudChatPanel.swift', r'Image\(systemName:.*person\.crop\.circle'),
    'stale_camera_linked_asset': (SRC / 'CloudChatPanel.swift', r'return "CameraLinked"'),
    'chat_feature_menu_sidebar': (SRC / 'CloudChatPanel.swift', r'CloudRoom\(title: "Remote Cam Control"|CloudRoom\(title: "Upload Status"'),
    'media_side_panel_unmounted': (SRC / 'GalleryView.swift', r'auxiliary panels are represented by toolbar/sidebar states'),
    'media_default_footer_status': (SRC / 'GalleryView.swift', r'RemoteClipSyncStatusFooterView\(status:'),
}


def read(path: Path) -> str:
    if not path.exists():
        raise AssertionError(f'missing file: {path}')
    return path.read_text(encoding='utf-8', errors='ignore')


def check_spec():
    if not SPEC_JSON.exists():
        raise AssertionError(f'missing generated reverse facts: {SPEC_JSON}')
    facts = json.loads(read(SPEC_JSON))
    source_ipa = facts.get('source_ipa', '')
    assert source_ipa.endswith('Blackmagic Cam_3.2.00.ipa'), source_ipa
    assert 'F:\\' not in source_ipa and 'F:/' not in source_ipa, source_ipa
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
    expected_fonts = [
        'BMD-Lato-Bold-Italic.ttf', 'BMD-Lato-Bold.ttf', 'BMD-Lato-Heavy.ttf', 'BMD-Lato-HeavyItalic.ttf',
        'BMD-Lato-Italic.ttf', 'BMD-Lato-Light-Italic.ttf', 'BMD-Lato-Light.ttf', 'BMD-Lato-Regular.ttf',
        'BMD-Lato-Timecode-Heavy.ttf', 'BMD-Lato-WP.ttf', 'BMD-Lato-WPAC.ttf'
    ]
    assert info.get('UIAppFonts') == expected_fonts, info.get('UIAppFonts')
    project_yml = read(ROOT / 'project.yml')
    assert 'CamControlAppUITests' in project_yml and 'bundle.ui-testing' in project_yml, 'launch UI smoke-test target missing from project.yml'
    for font in expected_fonts:
        assert f'- {font}' in project_yml, f'{font} missing from generated Info.plist properties'
    # Firmware/update note: these keys mirror the repo-local Blackmagic Cam_3.2.00.ipa Info.plist; rerun reverse_blackmagic_complete_ui.py before changing launch/status-bar behavior or permission UI text.


def check_swift_dictionary_literal_uniqueness():
    source = read(SRC / 'BlackmagicReverseSpec.swift')
    pattern = re.compile(r'static let (\w+)(?:\s*:\s*\[[^\]]+\])?\s*=\s*\[(.*?)\n\s*\]', re.S)
    duplicates = []
    for name, body in pattern.findall(source):
        if ':' not in body:
            continue
        keys = re.findall(r'"([^"]+)"\s*:', body)
        seen = set()
        for key in keys:
            if key in seen:
                duplicates.append(f'{name}.{key}')
            seen.add(key)
    if duplicates:
        raise AssertionError(f'duplicate Swift dictionary literal keys can SIGTRAP at launch: {duplicates}')
    # Firmware/update note: Swift dictionary literals trap on duplicate keys during one-time initialization; keep reverse-spec maps unique after each IPA refresh.


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




def check_page_rail_orientation_rules():
    txt = read(SRC / 'BlackmagicRootPageRail.swift')
    if 'Text(item.title.capitalized)' not in txt:
        raise AssertionError('portrait BmdTabView labels missing from bottom tab rail')
    if 'landscape page tabs are icon-only' not in txt:
        raise AssertionError('landscape icon-only page rail rule missing')
    if 'horizontal ? CGSize' not in txt or 'if horizontal' not in txt:
        raise AssertionError('page rail does not separate portrait horizontal tabs from landscape vertical tabs')
    # Firmware/update note: if a future IPA changes BmdTabView/BmdVTabView label behavior, update this orientation-specific rule from screenshots and symbols.



def check_online_features_deferred():
    combined = "\n".join(read(path) for path in SRC.glob("*.swift"))
    forbidden = ["URLSession", "URLRequest", "uploadTask", "dataTask", "NWConnection", "CKContainer", "CloudKit", "WebSocket"]
    hits = [token for token in forbidden if token in combined]
    if hits:
        raise AssertionError(f"online/cloud transport should stay deferred for this UI pass, found {hits}")
    # Firmware/update note: when online features are implemented, replace this guard with transport-specific tests while preserving the recovered Blackmagic UI hierarchy.


def check_media_fixture_resources():
    media_dir = ROOT / 'CamControlApp' / 'Resources' / 'BlackmagicSampleMedia'
    files = sorted(media_dir.glob('bmd_media_*.jpg'))
    if len(files) != 9:
        raise AssertionError(f'expected 9 cropped Blackmagic media fixtures, found {len(files)}')
    if any(f.stat().st_size < 3000 for f in files):
        raise AssertionError('one or more Blackmagic media fixture crops look empty/truncated')
    # Firmware/update note: these crops come from the official 3.2.00 MediaView screenshot and should be regenerated when screenshots/IPA evidence changes.

def main():
    checks = [check_spec, check_info_plist_parity, check_swift_dictionary_literal_uniqueness, check_source_patterns, check_hud_labels, check_asset_coverage, check_page_rail_orientation_rules, check_online_features_deferred, check_media_fixture_resources]
    for check in checks:
        check()
    print('blackmagic-ui-alignment: PASS')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'blackmagic-ui-alignment: FAIL: {exc}', file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env bash
# A configuration gate, not proof of an App Store-ready binary.
set -euo pipefail
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ios_directory="$(cd -- "$script_directory/.." && pwd)"
python3 "$script_directory/generate-xcode-project.py" --check
python3 - "$ios_directory" <<'PY'
from pathlib import Path
import json
import plistlib
import re
import struct
import sys
from urllib.parse import urlparse
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
errors = []
variables = {}

def read_config(path, stack=()):
    if path in stack:
        raise ValueError('Circular xcconfig include: ' + str(path))
    for raw in path.read_text().splitlines():
        line = raw.strip()
        include = re.fullmatch(r'#include\s+"([^"]+)"', line)
        if include:
            read_config(path.parent / include.group(1), (*stack, path))
            continue
        line = line.split('//', 1)[0].strip()
        assignment = re.fullmatch(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)', line)
        if assignment:
            variables[assignment.group(1)] = assignment.group(2).strip()

read_config(root / 'Config/Release.xcconfig')

def expand(value, depth=0):
    if depth > 20:
        raise ValueError('Circular build-setting substitution.')
    updated = re.sub(r'\$\(([^)]*)\)', lambda m: variables.get(m.group(1), ''), value)
    return expand(updated, depth + 1) if updated != value else updated

bundle = expand(variables.get('PRODUCT_BUNDLE_IDENTIFIER', ''))
team = expand(variables.get('DEVELOPMENT_TEAM', ''))
product = expand(variables.get('PRO_PRODUCT_ID', ''))
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}', bundle) or any(term in bundle.lower() for term in ['example', 'yourcompany', 'placeholder', 'changeme']):
    errors.append('Set STUDIO_BUNDLE_IDENTIFIER to your registered production bundle identifier in Config/Publisher.xcconfig.')
if not re.fullmatch(r'[A-Z0-9]{10}', team):
    errors.append('Set DEVELOPMENT_TEAM to your 10-character Apple Developer Team ID.')
if not product or product != bundle + '.pro' or any(term in re.split(r'[._-]', product.lower()) for term in ['example', 'test', 'testing', 'sandbox', 'debug', 'placeholder', 'changeme']):
    errors.append('Set PRO_PRODUCT_ID to the production nonconsumable product identifier registered in App Store Connect (<bundle identifier>.pro).')

for key in ['STUDIO_PRIVACY_POLICY_URL', 'STUDIO_TERMS_OF_USE_URL', 'STUDIO_SUPPORT_URL']:
    value = expand(variables.get(key, ''))
    parsed = urlparse(value)
    host = (parsed.hostname or '').lower()
    invalid_host = not host or '.' not in host or host == 'localhost' or host.endswith(('.invalid', '.test', '.localhost', '.example')) or any(part in host for part in ['example.', '.example', 'your-domain', 'placeholder', 'changeme'])
    if parsed.scheme != 'https' or invalid_host or parsed.username or parsed.password:
        errors.append(f'Set {key} to a public HTTPS page. In xcconfig use https:/$()/your-real-domain/path to escape the comment delimiter.')
if 'DEBUG' in expand(variables.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '')).split():
    errors.append('Release configuration must not include the DEBUG compilation condition.')
if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', expand(variables.get('MARKETING_VERSION', ''))):
    errors.append('MARKETING_VERSION must be an App Store version such as 1.0.0.')
if not re.fullmatch(r'[1-9]\d*(?:\.\d+){0,2}', expand(variables.get('CURRENT_PROJECT_VERSION', ''))):
    errors.append('CURRENT_PROJECT_VERSION must be a positive build number.')

info = plistlib.loads((root / 'BlackjackStudio/Resources/Info.plist').read_bytes())
for key, variable in [('CFBundleIdentifier', 'PRODUCT_BUNDLE_IDENTIFIER'), ('ProProductID', 'PRO_PRODUCT_ID'), ('PrivacyPolicyURL', 'STUDIO_PRIVACY_POLICY_URL'), ('TermsOfUseURL', 'STUDIO_TERMS_OF_USE_URL'), ('SupportURL', 'STUDIO_SUPPORT_URL')]:
    if info.get(key) != f'$({variable})':
        errors.append(f'Info.plist {key} must derive from $({variable}).')
if info.get('ITSAppUsesNonExemptEncryption') is not False:
    errors.append('Reassess and explicitly declare the app encryption export status before release.')
privacy = plistlib.loads((root / 'BlackjackStudio/Resources/PrivacyInfo.xcprivacy').read_bytes())
if privacy.get('NSPrivacyTracking') is not False or privacy.get('NSPrivacyCollectedDataTypes') != []:
    errors.append('Privacy manifest no longer matches the local-only, no-tracking design; review the implementation and App Store disclosures.')
accessed = {entry.get('NSPrivacyAccessedAPIType'):entry.get('NSPrivacyAccessedAPITypeReasons', []) for entry in privacy.get('NSPrivacyAccessedAPITypes', [])}
if '35F9.1' not in accessed.get('NSPrivacyAccessedAPICategorySystemBootTime', []):
    errors.append('Declare system-uptime access reason 35F9.1 for within-app drill elapsed-time measurements.')

icon_directory = root / 'BlackjackStudio/Resources/Assets.xcassets/AppIcon.appiconset'
icon_manifest = icon_directory / 'Contents.json'
if not icon_manifest.is_file():
    errors.append('Add an AppIcon asset catalog with a 1024×1024 opaque PNG.')
else:
    images = json.loads(icon_manifest.read_text()).get('images', [])
    candidates = [item for item in images if item.get('filename') and (item.get('size') == '1024x1024' or item.get('idiom') == 'ios-marketing')]
    if not candidates:
        errors.append('AppIcon must include a 1024×1024 App Store image.')
    for item in candidates:
        image = icon_directory / item['filename']
        if not image.is_file():
            errors.append('An AppIcon image referenced by Contents.json is missing.')
            continue
        data = image.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 33:
            errors.append('The 1024×1024 App Store icon must be a valid PNG.')
            continue
        width,height = struct.unpack('>II', data[16:24])
        if (width,height) != (1024,1024):
            errors.append('The App Store icon must be exactly 1024×1024 pixels.')
        position = 8
        transparent = data[25] in (4,6)
        while position + 12 <= len(data):
            length = struct.unpack('>I', data[position:position+4])[0]
            chunk_type = data[position+4:position+8]
            if position + length + 12 > len(data):
                errors.append('The App Store icon contains a truncated PNG chunk.')
                break
            transparent = transparent or chunk_type == b'tRNS'
            position += length + 12
            if chunk_type == b'IEND':
                break
        if transparent:
            errors.append('Remove the alpha channel/transparency from the App Store icon.')

release_scheme = ET.parse(root / 'BlackjackStudio.xcodeproj/xcshareddata/xcschemes/BlackjackStudio Release.xcscheme').getroot()
if release_scheme.findall('.//StoreKitConfigurationFileReference'):
    errors.append('The Release scheme must not attach a local StoreKit test configuration.')

if errors:
    print('Release configuration is incomplete:', file=sys.stderr)
    for error in errors:
        print(' - ' + error, file=sys.stderr)
    print('No signing, upload, or publication was attempted.', file=sys.stderr)
    sys.exit(1)
print('Release configuration checks passed.')
print('This does not verify App Store registration, hosted URL availability, signing, native builds, purchases, or App Review approval.')
print('Complete the macOS/Xcode, device, StoreKit sandbox, and submission checks in Documentation/RELEASE.md.')
PY

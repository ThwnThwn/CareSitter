#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Cần macOS/Xcode để build và ký ứng dụng iPhone. Windows không chạy được bước này.' >&2
  exit 2
fi
if [[ $# -ne 1 ]]; then
  echo 'Dùng: bash tool/run_lab3_iphone.sh <device-id từ flutter devices>' >&2
  exit 2
fi
for command in flutter xcodebuild python3 pod; do
  command -v "$command" >/dev/null || { echo "Thiếu công cụ: $command" >&2; exit 2; }
done
xcodebuild -version
[[ -f .env.local ]] || { echo 'Thiếu .env.local (cấu hình client, không chứa service-account).' >&2; exit 2; }
python3 - <<'PY'
from pathlib import Path
import json, plistlib
from urllib.parse import urlparse
p=Path('.env.local'); text=p.read_text(encoding='utf-8-sig')
if text.lstrip().startswith('{'):
    values=json.loads(text)
else:
    values={k.strip():v.strip().strip('"').strip("'") for line in text.splitlines()
        if '=' in line and not line.lstrip().startswith('#') for k,v in [line.split('=',1)]}
for key in ['BASE_URL','HUB_BASE_URL']:
    url=urlparse(values.get(key,''))
    if url.scheme!='https' or not url.hostname or url.hostname in ['localhost','127.0.0.1','10.0.2.2']:
        raise SystemExit('Cần '+key+' là URL HTTPS truy cập được từ iPhone.')
client=values.get('GOOGLE_IOS_CLIENT_ID','')
if not client.endswith('.apps.googleusercontent.com'):
    raise SystemExit('Thiếu GOOGLE_IOS_CLIENT_ID hợp lệ.')
with Path('ios/Runner/GoogleService-Info.plist').open('rb') as f: config=plistlib.load(f)
if config.get('BUNDLE_ID')!='vn.caresitter.customer' or config.get('PROJECT_ID')!='caresitter-947d2':
    raise SystemExit('Firebase native config không khớp Customer.')
Path('ios/Flutter/GoogleSignIn.local.xcconfig').write_text(
    '// Generated locally; do not commit.\nGOOGLE_REVERSED_CLIENT_ID = '+'.'.join(reversed(client.split('.')))+'\n')
print('PASS: Firebase, OAuth callback và URL client. Không hiển thị credential.')
PY
device_list="$(mktemp)"
trap 'rm -f "$device_list"' EXIT
flutter devices --machine > "$device_list"
python3 - "$device_list" "$1" <<'PY'
import json,sys
devices=json.load(open(sys.argv[1]))
match=[d for d in devices if d.get('id')==sys.argv[2] and d.get('targetPlatform')=='ios' and not d.get('emulator',True)]
if not match: raise SystemExit('Chưa thấy iPhone thật đã trust/unlock. Simulator không đủ để nghiệm thu.')
print('PASS: đã chọn iPhone thật.')
PY
flutter pub get
echo 'Xcode phải có Development Team, profile hỗ trợ Push Notifications và iPhone đã bật Developer Mode.'
echo 'Sau khi cài, detach debugger và mở app bằng biểu tượng trước khi thử nút crash.'
flutter run -d "$1" --debug --dart-define-from-file=.env.local --dart-define=LAB3_DEMO_ENABLED=true

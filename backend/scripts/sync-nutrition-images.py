"""Upload attributed recipe photos using local Cloudinary configuration."""

import argparse
import concurrent.futures
import hashlib
import json
import os
import time
from pathlib import Path
from urllib.parse import urlparse

import requests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upload', action='store_true')
    args = parser.parse_args()
    backend = Path(__file__).resolve().parent.parent
    path = backend / 'services/nutrition/catalog/sources/nutrition-recipe-images.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    cache = backend / 'artifacts/nutrition-image-intake'
    cache.mkdir(parents=True, exist_ok=True)
    config = {}
    for line in (backend / '.env').read_text(encoding='utf-8-sig').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            config[key.strip()] = value.strip().strip('\"\x27')
    config.update(os.environ)
    cloud = config.get('Cloudinary__CloudName', '')
    api_key = config.get('Cloudinary__ApiKey', '')
    api_secret = config.get('Cloudinary__ApiSecret', '')
    if args.upload and not all((cloud, api_key, api_secret)):
        raise RuntimeError('Local Cloudinary configuration is incomplete.')

    def sync(item):
        key, source_asset = item
        asset = dict(source_asset)
        source_hash = hashlib.sha256(asset['originalImageUrl'].encode()).hexdigest()[:12]
        image = cache / (key + '-' + source_hash + '.image')
        if not image.exists():
            for attempt in range(3):
                try:
                    response = requests.get(asset['originalImageUrl'], timeout=30)
                    response.raise_for_status()
                    if not response.headers.get('Content-Type', '').startswith('image/'):
                        raise RuntimeError('The source did not return image content: ' + key)
                    if not 1000 <= len(response.content) <= 10 * 1024 * 1024:
                        raise RuntimeError('Image size is outside accepted limits: ' + key)
                    image.write_bytes(response.content)
                    break
                except requests.RequestException:
                    if attempt == 2:
                        raise RuntimeError('Image download failed: ' + key) from None
        digest = hashlib.sha256(image.read_bytes()).hexdigest()
        asset['fileSha256'] = digest
        if args.upload and (not asset.get('url') or not asset.get('publicId', '').endswith(digest[:12])):
            fields = {'public_id': 'CareSitter/Nutrition/catalog/' + key + '-' + digest[:12],
                      'timestamp': str(int(time.time())), 'overwrite': 'false'}
            signature = hashlib.sha1(('&'.join(k + '=' + fields[k] for k in sorted(fields)) + api_secret).encode()).hexdigest()
            with image.open('rb') as stream:
                response = requests.post('https://api.cloudinary.com/v1_1/' + cloud + '/image/upload',
                    data={**fields, 'api_key': api_key, 'signature': signature},
                    files={'file': (key + '.jpg', stream, 'application/octet-stream')}, timeout=60)
            if response.status_code != 200:
                raise RuntimeError('Cloudinary upload failed for ' + key + ' (HTTP ' + str(response.status_code) + ').')
            uploaded = response.json()
            asset['url'] = uploaded['secure_url']
            asset['publicId'] = uploaded['public_id']
            asset['width'] = uploaded['width']
            asset['height'] = uploaded['height']
        if asset.get('url') and urlparse(asset['url']).scheme != 'https':
            raise RuntimeError('Image URL must use HTTPS: ' + key)
        return key, asset

    errors = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(sync, item): item[0] for item in manifest['assets'].items()}
        for future in concurrent.futures.as_completed(futures):
            try:
                key, asset = future.result()
                manifest['assets'][key] = asset
                temporary = path.with_suffix('.tmp')
                temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                temporary.replace(path)
                print('Ready ' + key, flush=True)
            except Exception as error:
                errors.append(futures[future] + ': ' + str(error))
    if errors:
        raise RuntimeError('\n'.join(errors))
    print(str(len(manifest['assets'])) + ' attributed images checked.')


if __name__ == '__main__':
    main()

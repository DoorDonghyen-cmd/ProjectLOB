"""Acquire pinned public source snapshots. Never install or execute upstream code.
Default resumes the recorded revision. --verify is offline and checks every file.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import urllib.request
import zipfile
import argparse

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'reference_library'
LOCK = LIB / 'sources.lock.json'
CACHE = LIB / 'cache'
HEADERS = {'User-Agent': 'ProjectLoB-reference-acquisition', 'Accept': 'application/vnd.github+json'}


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): h.update(block)
    return h.hexdigest()


def api(path):
    with urllib.request.urlopen(urllib.request.Request('https://api.github.com/'+path, headers=HEADERS), timeout=40) as response:
        return json.load(response)


def verify(entry):
    base = ROOT / entry['directory']
    manifest = LIB / entry['manifest']
    if sha(manifest) != entry['manifest_sha256']: raise ValueError('Changed manifest: '+entry['id'])
    files = json.loads(manifest.read_text(encoding='utf-8'))
    for relative, digest in files.items():
        path = (base / relative).resolve()
        if not path.is_relative_to(base.resolve()): raise ValueError('Unsafe manifest path')
        if sha(path) != digest: raise ValueError('Changed source: '+str(path))
    for notice in entry.get('notices', []):
        relative = PurePosixPath(notice).relative_to(PurePosixPath('notices') / entry['id']).as_posix()
        if sha(LIB / notice) != files[relative]: raise ValueError('Changed notice: '+notice)
    archive = ROOT / entry['archive']
    if sha(archive) != entry['archive_sha256']: raise ValueError('Changed archive: '+entry['id'])
    return len(files)


def acquire(spec, previous):
    if previous:
        try:
            verify(previous)
            if any(not (ROOT / previous['directory'] / p).is_file() for p in spec.get('extra_files', [])):
                raise ValueError('Supplement pinned metadata excluded by git archive')
            print('VERIFIED '+spec['id'], flush=True)
            return previous
        except (OSError, ValueError):
            # Missing local cache can be recovered from the same pinned commit.
            pass
    repo = spec['repo']
    meta = api('repos/'+repo)
    revision = previous['commit'] if previous else api('repos/'+repo+'/commits/'+spec.get('ref', meta['default_branch']))['sha']
    base = CACHE / spec['id'] / revision
    base.mkdir(parents=True, exist_ok=True)
    archive = base / 'source.zip'
    url = 'https://codeload.github.com/'+repo+'/zip/'+revision
    if not archive.exists() or (previous and sha(archive) != previous['archive_sha256']):
        pending = base / 'source.download'
        print('DOWNLOAD '+spec['id']+' '+revision[:12], flush=True)
        with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=90) as response, pending.open('wb') as output:
            size = 0
            while block := response.read(1024*1024):
                size += len(block)
                if size > 512*1024*1024: raise ValueError('Archive exceeds 512 MiB limit')
                output.write(block)
        if previous and sha(pending) != previous['archive_sha256']: raise ValueError('Pinned archive hash mismatch')
        pending.replace(archive)
    files = {}
    notices = []
    source = base / 'source'
    source.mkdir(exist_ok=True)
    expanded = 0
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            parts = PurePosixPath(member.filename).parts
            if member.is_dir() or len(parts) < 2: continue
            relative = PurePosixPath(*parts[1:])
            if any(p in ('..', '.', '') or ':' in p or '\\' in p for p in relative.parts): raise ValueError('Unsafe zip path')
            mode = member.external_attr >> 16
            if stat.S_ISLNK(mode): raise ValueError('Symlink in archive: '+str(relative))
            name = relative.name.lower()
            notice = name.startswith(('license','copying','copyright','notice','credits','authors'))
            keep = not spec.get('include') or len(relative.parts)==1 or notice or any(str(relative).startswith(p) for p in spec['include'])
            if not keep: continue
            expanded += member.file_size
            if expanded > 1024*1024*1024: raise ValueError('Expanded snapshot exceeds 1 GiB limit')
            target = (source / str(relative)).resolve()
            if not target.is_relative_to(source.resolve()): raise ValueError('Zip traversal')
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(member) as incoming, target.open('wb') as outgoing: shutil.copyfileobj(incoming, outgoing)
            files[str(relative)] = sha(target)
            if notice:
                copy = LIB / 'notices' / spec['id'] / str(relative)
                copy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(target, copy)
                notices.append(str(copy.relative_to(LIB)).replace('\\','/'))
    for relative in spec.get('extra_files', []):
        if PurePosixPath(relative).name != relative: raise ValueError('Only root metadata supplements allowed')
        request = urllib.request.Request('https://raw.githubusercontent.com/'+repo+'/'+revision+'/'+relative, headers=HEADERS)
        with urllib.request.urlopen(request, timeout=40) as response:
            content = response.read(1024*1024+1)
            if len(content) > 1024*1024: raise ValueError('Oversized metadata supplement')
        target = source / relative
        target.write_bytes(content)
        files[relative] = sha(target)
        expanded += len(content)
        if relative.lower().startswith(('license','copying','copyright','notice','credits')):
            copy = LIB / 'notices' / spec['id'] / relative
            copy.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target, copy)
            notices.append(copy.relative_to(LIB).as_posix())
    manifest = LIB / 'manifests' / (spec['id']+'.json')
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(files, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    result = {**spec, 'commit':revision, 'url':'https://github.com/'+repo,
              'acquired_utc': datetime.now(timezone.utc).isoformat(),
              'license_api': (meta.get('license') or {}).get('spdx_id','UNSPECIFIED'),
              'archive':archive.relative_to(ROOT).as_posix(), 'archive_sha256':sha(archive),
              'directory':source.relative_to(ROOT).as_posix(), 'file_count':len(files), 'source_bytes':expanded,
              'manifest':manifest.relative_to(LIB).as_posix(), 'manifest_sha256':sha(manifest),
              'notices':notices, 'status':'acquired_reference_only', 'runtime_enabled':False}
    verify(result)
    print('ACQUIRED '+spec['id']+' files='+str(len(files))+' license='+result['license_api'], flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    specs = json.loads((ROOT / 'tools/reference_sources.json').read_text(encoding='utf-8'))['sources']
    lock = json.loads(LOCK.read_text(encoding='utf-8')) if LOCK.exists() else {'version':1,'sources':[]}
    prior = {row['id']:row for row in lock['sources']}
    if args.verify:
        assert set(prior)=={s['id'] for s in specs}, 'Missing sources'
        count = sum(verify(entry) for entry in prior.values())
        print(f'REFERENCE VERIFY PASS sources={len(prior)} files={count}')
        return
    errors = []
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = {pool.submit(acquire, spec, prior.get(spec['id'])):spec for spec in specs}
        for future in as_completed(jobs):
            spec = jobs[future]
            try: prior[spec['id']] = future.result()
            except Exception as error:
                errors.append(spec['id']+': '+str(error))
                print('FAILED '+errors[-1], flush=True)
            lock['sources'] = sorted(prior.values(), key=lambda row:row['id'])
            LIB.mkdir(exist_ok=True)
            LOCK.write_text(json.dumps(lock, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    if errors: raise SystemExit('\n'.join(errors))
    print('REFERENCE ACQUISITION COMPLETE sources='+str(len(prior)))


if __name__ == '__main__': main()

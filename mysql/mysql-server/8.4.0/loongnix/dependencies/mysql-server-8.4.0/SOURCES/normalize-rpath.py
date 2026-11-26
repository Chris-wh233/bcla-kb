#!/usr/bin/python3
"""Normalize installed MySQL private-library RPATHs before native RPM checks."""
from pathlib import Path
import json,subprocess,sys
root=Path(sys.argv[1]); build=Path(sys.argv[2]); report=Path(sys.argv[3]); changes=[]
for directory in ['usr/bin','usr/sbin','usr/lib/mysql','usr/lib/mysqlrouter']:
 base=root/directory
 if not base.exists():continue
 for p in sorted(base.rglob('*')):
  if not p.is_file() or p.is_symlink():continue
  with p.open('rb') as stream:
   if stream.read(4)!=b'\x7fELF':continue
  r=subprocess.run(['patchelf','--print-rpath',str(p)],capture_output=True,text=True)
  if r.returncode:continue
  old=r.stdout.strip()
  if not old:continue
  paths=[]
  for value in old.split(':'):
   if not value or value.startswith(str(build)):continue
   value=value.rstrip('/') or '/'
   if value not in paths:paths.append(value)
  paths=[x for x in paths if x.startswith('$ORIGIN')]+[x for x in paths if not x.startswith('$ORIGIN')]
  new=':'.join(paths)
  if new!=old:
   command=['patchelf','--set-rpath',new,str(p)] if new else ['patchelf','--remove-rpath',str(p)]
   subprocess.run(command,check=True)
   changes.append({'file':'/'+str(p.relative_to(root)),'before':old,'after':new})
report.write_text(json.dumps(changes,indent=2)+'\n')
print('Normalized private RPATHs:',len(changes),flush=True)


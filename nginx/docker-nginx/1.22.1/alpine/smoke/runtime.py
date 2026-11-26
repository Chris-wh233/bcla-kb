import subprocess,tempfile,json,time
from pathlib import Path
image='lcr.loongnix.cn/library/nginx:1.22.1-alpine'
def run(*args):
    return subprocess.run(['docker',*args],check=True,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout
info=json.loads(run('image','inspect',image))[0]
print('IMAGE',info['Id'],info['Architecture'],'STOPSIGNAL',info['Config'].get('StopSignal'),flush=True)
assert info['Config'].get('StopSignal')=='SIGQUIT'
containers=[]
try:
    with tempfile.TemporaryDirectory(prefix='nginx-runtime-smoke-') as directory:
        template=Path(directory)/'default.conf.template'
        template.write_text('server { listen 80; server_name localhost; location / { return 200 "${TEST_MESSAGE}\\n"; } }\n')
        for kind in ['http','template']:
            args=['run','-d','--network','none']
            if kind=='template':
                args+=['-e','TEST_MESSAGE=template-substitution-ok','-v',str(template)+':/etc/nginx/templates/default.conf.template:ro']
            cid=run(*args,image).strip(); containers.append(cid)
            body=None
            for attempt in range(30):
                response=subprocess.run(['docker','exec',cid,'curl','-fsS','http://127.0.0.1/'],capture_output=True,text=True)
                if response.returncode==0:
                    body=response.stdout;break
                if not json.loads(run('inspect',cid))[0]['State']['Running']:
                    raise RuntimeError(run('logs',cid))
                time.sleep(0.2)
            assert body is not None,'HTTP startup timed out'
            if kind=='http':
                assert 'Welcome to nginx!' in body
                print('PASS default HTTP 200 / Welcome to nginx!',flush=True)
            else:
                assert body=='template-substitution-ok\n',repr(body)
                generated=run('exec',cid,'cat','/etc/nginx/conf.d/default.conf')
                assert '${TEST_MESSAGE}' not in generated
                assert 'template-substitution-ok' in generated
                print('PASS template envsubst / HTTP 200 / expected body',flush=True)
            env=run('exec',cid,'env')
            assert not any(line.split('=',1)[0].lower() in ['http_proxy','https_proxy','all_proxy'] for line in env.splitlines())
            run('stop','-t','15',cid)
            state=json.loads(run('inspect',cid))[0]['State']
            log=run('logs',cid)
            assert state['ExitCode']==0,state
            assert not state['OOMKilled']
            assert 'signal 3 (SIGQUIT) received' in log,log
            assert 'gracefully shutting down' in log,log
            print('PASS',kind,'SIGQUIT received / graceful shutdown / exit 0',flush=True)
        print('PASS all requested tests; isolated network, no proxy environment',flush=True)
finally:
    for cid in containers:
        subprocess.run(['docker','rm','-f',cid],capture_output=True,text=True,check=True)

# MySQL 8.4.0 on LoongArch64 / Debian forky

Verified target: mysql:8.4.0-loong64, exact MySQL 8.4.0. The native DEB build and twelve separately retained binary packages are documented in dependencies/mysql-server-8.4.0. This recipe preserves the final accepted Dockerfile and the unmodified official docker-library/mysql entrypoint. It installs prepared DEBs into Debian forky; it does not build MySQL inside the final Dockerfile.

## Critical prepared artifacts

| Input | Consumer | Acquisition / identity |
|---|---|---|
| Native twelve MySQL DEBs | Runtime image consumes nine; development/testsuite packages remain deliverables | Build the flat dependency recipe, or reuse bytes matching its mysql-packages.json |
| Seventy forky OS runtime DEBs | Dockerfile COPY runtime-deps; offline APT installation | Reuse retained task artifacts matching runtime-dependencies.json; otherwise acquire exact package=version through configured forky APT repositories and verify each SHA256 |
| Pinned forky base | Native build helper and runtime FROM | Pull the immutable lcr.loongnix.cn digest in source-provenance.json / Dockerfile |
| MySQL source archive / GNU config inputs | DEB producer | Official archive and captured helper input hashes in the dependency recipe |
| docker-entrypoint.sh | Runtime initialization and privileges | Exact included bytes from docker-library/mysql c05422492215b3f0602409288c868ee4fd606ac3, 8.4/docker-entrypoint.sh |

The repository stores recipes, patches, scripts and manifests, not binary DEBs/image archives. Prepared binaries and task-local execution logs are retained by BCLA on the build machine. A moving forky mirror may no longer serve historical versions; missing exact bytes require reacquisition/revalidation, not silently claiming the old image ID for new inputs.

## Build flow

First follow the flat dependency README in a native forky helper. Set RECIPE_DIR to this main recipe directory, WORKSPACE to that DEB build workspace, IMAGE_CONTEXT to a fresh context directory and ARTIFACTS_DIR to a writable output directory. Paths must be accessible to the helper and its Docker daemon for any bind-mount tests.

```sh
mkdir -p "$IMAGE_CONTEXT/debs" "$IMAGE_CONTEXT/runtime-deps" "$ARTIFACTS_DIR/debs"
cp "$RECIPE_DIR/Dockerfile" "$RECIPE_DIR/docker-entrypoint.sh" "$IMAGE_CONTEXT/"
cp "$WORKSPACE"/src/*.deb "$ARTIFACTS_DIR/debs/"
for pkg in libmysqlclient24 mysql-client mysql-common mysql-community-client-core mysql-community-client-plugins mysql-community-client mysql-community-server-core mysql-community-server mysql-server; do
  cp "$WORKSPACE/src/${pkg}_8.4.0-1debian14_loong64.deb" "$IMAGE_CONTEXT/debs/"
done
```

Populate runtime-deps with the seventy verified OS DEBs from the manifest. During the accepted build APT acquired the closure using an empty temporary status database, --download-only --no-install-recommends, all nine local MySQL DEBs plus gosu bzip2 gzip openssl xz-utils zstd findutils tzdata tzdata-legacy ca-certificates. To reacquire the recorded set exactly, run this in a writable directory with the helper's configured forky repository indexes:

```sh
export RECIPE_DIR IMAGE_CONTEXT
python3 - <<'ACQUIRE'
import hashlib,json,os,pathlib,subprocess,tempfile
recipe=pathlib.Path(os.environ['RECIPE_DIR'])
out=pathlib.Path(os.environ['IMAGE_CONTEXT'])/'runtime-deps'
for item in json.loads((recipe/'runtime-dependencies.json').read_text()):
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        subprocess.run(['apt-get','download',item['package']+'='+item['version']],cwd=tmp,check=True)
        candidates=list(pathlib.Path(tmp).glob('*.deb')); assert len(candidates)==1
        data=candidates[0].read_bytes()
        assert hashlib.sha256(data).hexdigest()==item['sha256'],item['file']
        (out/item['file']).write_bytes(data)
ACQUIRE
cd "$IMAGE_CONTEXT"
docker build --network=none --tag mysql:8.4.0-loong64 .
docker image inspect mysql:8.4.0-loong64
# Run initialization, SQL, timing, TLS and persistence checks before accepting new artifacts.
docker save mysql:8.4.0-loong64 | gzip -1 > "$ARTIFACTS_DIR/mysql-8.4.0-loong64.tar.gz"
gzip -t "$ARTIFACTS_DIR/mysql-8.4.0-loong64.tar.gz"
sha256sum "$ARTIFACTS_DIR/mysql-8.4.0-loong64.tar.gz"
```

The exact-version download loop is a manifest-based reacquisition aid; it was not rerun during experience generation. Accepted image assembly used the retained validated cache, Docker's Unix socket and --network=none. The final image was tagged after validation. No download or build is being claimed for this experience-generation operation.

## Verified output and scope

Image ID: sha256:0d1f4915989e3ec4b55a4d81cb0442e63d044be767062b7606cd63baeff6ef79; linux/loong64. Archive SHA256: 055d3b34109f3a0408dc09721b08129d87d4915a68798d094f955f98d624e1df (253402806 bytes). These identify the accepted historical output, not a guarantee of byte-identical future rebuilding.

Actual final-image checks passed: official entrypoint initialization; server 8.4.0; clean dpkg audit; UID 999; cross-container TCP/TLS; InnoDB transactions/rollback, JSON/utf8mb4, indexed rows/join/temp tables; timezone tables; InnoDB and mysqlx ACTIVE; group_replication plugin loading; mysqldump restore; restart persistence and one-time initialization; graceful shutdown; authentication client shared-library closure; upstream Debian service/tmpfiles payload and unique conffiles. Plugin loading is not multi-node replication certification.

CYCLE timer frequency is nonzero (~99.8 MHz), and SLEEP(0.2) produced a 0.20046488952-second wait with no CYCLE warning. Timer, CSR, tmpfs temporary-file and CET checks passed. Full CTest was 134/136, not all passing: helper filesystem tempfile failure passes on tmpfs, while the synthetic hash distribution assertion remains an explicit limitation. No identified correctness/availability impact; workload-specific efficiency is unbenchmarked. Full NDB cluster integration was not tested. Shell and Router are optional omissions. See adaptation.md, verification.json and unit-rechecks.json.

Task-local execution IDs in experience.json refer to retained remote BCLA evidence and are not public URLs. Schema/hash validation verifies recorded structure and bytes; this generation did not repeat the build or runtime tests.

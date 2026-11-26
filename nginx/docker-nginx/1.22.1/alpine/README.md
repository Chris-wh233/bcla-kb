# Nginx 1.22.1 Alpine / LoongArch64

Recommended target: `lcr.loongnix.cn/library/nginx:1.22.1-alpine`, based on `lcr.loongnix.cn/library/alpine:3.24.4`. The verified maker image is `sha256:06fdb06b2cfec3cfaf6166fc054b9fefc7fc6937b16afc8e02a270db1639859f`, linux/loong64, 52,311,329 bytes.

## Build flow and upstream style

Use the retained single-stage Dockerfile. It follows the source-build branch of the [nginx 1.22.1 official Alpine Dockerfile](https://github.com/nginx/docker-nginx/blob/fef51235521d1cdf8b05d8cb1378a526d2abf421/stable/alpine/Dockerfile): create the nginx user, define nginxPackages, build with official pkg-oss as nobody, index/sign APKs, remove .build-deps, install runtime packages, and remove temporary files. Downloads, compilation, package installation and cleanup occur within one RUN, using the upstream command order and && layout.

Do not introduce another build stage, stage-to-stage APK/cache COPY, a separately compiled binary prerequisite, or an offline source/cache bundle for this recipe. The previous recipe's large APK COPY layer persisted even after its files were deleted in a later layer. The maker flow avoids that unused layer while retaining the runtime package selection and compilation options.

This is the actual successfully built maker Dockerfile, copied without reconstruction. Its RUN content was checked against the new immutable image's recorded build history. The original BCLA task supplies the source/patch provenance; subsequent user build and conversation tests supply the accepted single-stage image evidence. See [adaptation.md](adaptation.md), [njs dependency](dependencies/njs-0.7.7/README.md), and [existing evidence](verification/existing-evidence.json).

## Required inputs

| Input | Source and consumer |
| --- | --- |
| Base image | lcr.loongnix.cn/library/alpine:3.24.4; digest sha256:c33c932f192e734f5880740bbec2ed7d43f4ae898804ed06c3836aebe7fa6dee |
| pkg-oss | Dockerfile downloads commit873a91379b6884c29e9cd00dc6a35a7c93102891, official tag1.22.1-1 |
| nginx source | Dockerfile downloads https://nginx.org/download/nginx-1.22.1.tar.gz; official packaging retains its nginx SHA512 verification |
| njs source | Dockerfile downloads GitHub tag0.7.7, corresponding to commit6af74b6c5e120595e11df74ca8749021e5f2a7e1, applies njs-webcrypto.patch, repacks and regenerates its packaging SHA512 entry |
| Signed Alpine dependencies | Dockerfile installs v3.24 main/community packages using the TUNA mirror, then restores the original repository configuration |
| Small local files | abuild-compat.conf, njs-webcrypto.patch and the four entrypoint scripts are included and consumed by COPY |

No local binary archives, prebuilt APKs, cache directories or checksum manifests are build prerequisites. njs-webcrypto.patch is byte-identical to dependencies/njs-0.7.7/patches/loongarch.patch; the root copy provides the Dockerfile's flat input name. Local file hashes in experience.json identify recipe contents and are not Dockerfile SHA256 checks.

## Reuse

Set RECIPE to this directory and IMAGE_CONTEXT to an empty writable context directory. Build on native Linux LoongArch64 with a Docker daemon and network access. Project commands belong in a compatible helper when reusing through BCLA.

```sh
mkdir -p "$IMAGE_CONTEXT"
cp "$RECIPE/Dockerfile" "$RECIPE/.dockerignore" "$RECIPE/abuild-compat.conf" "$RECIPE/njs-webcrypto.patch" "$IMAGE_CONTEXT/"
cp "$RECIPE/docker-entrypoint.sh" "$RECIPE/10-listen-on-ipv6-by-default.sh" "$RECIPE/20-envsubst-on-templates.sh" "$RECIPE/30-tune-worker-processes.sh" "$IMAGE_CONTEXT/"
cd "$IMAGE_CONTEXT"
chmod +x docker-entrypoint.sh 10-listen-on-ipv6-by-default.sh 20-envsubst-on-templates.sh 30-tune-worker-processes.sh
docker build -t lcr.loongnix.cn/library/nginx:1.22.1-alpine .
```

Compilation remains inside this Dockerfile: official pkg-oss alpine make all produces nginx and module packages, including njs CLI, then installs the official runtime selection (nginx, xslt, GeoIP, image-filter, njs). Perl and debug package outputs are produced by make all and removed with the temporary build directory; there is no independent artifact export requirement.

Repository package revisions, build timestamps and generated signing keys can vary. The saved inventory records observed runtime versions, not a frozen dependency cache or a promise of a byte-identical rebuild.

## Existing verification

The new maker image has already passed:

- nginx1.22.1 and njs0.7.7 version inspection, 69 installed package names matching the original image, and identical nginx configure options.
- nginx -t with all six dynamic modules loaded, plus WebCrypto AES-GCM and invalid key-format handling.
- Default HTTP200 welcome page and template environment substitution with the expected HTTP200 response.
- SIGQUIT receipt, graceful shutdown log and exit0 for both default and template containers, with isolated networking and no proxy environment.

The actual successful HTTP/template/shutdown Python body is retained in smoke/runtime.py. It originally ran through python3 stdin; it can be reused with `python3 smoke/runtime.py` after setting up the same daemon access. Module inputs and WebCrypto script remain in smoke/. smoke/run.sh is the optional broader regression suite, with its target default updated; the new-image evidence above does not claim that this entire broader script was rerun (in particular, its njs HTTP handler and stub_status assertions).

Evidence IDs beginning codex-output refer to existing conversation tool outputs, not BCLA execution-table rows. The build evidence uses the immutable image history and user-reported build, rather than assigning old two-stage BCLA execution IDs to the new image. The reusable build command is shown above; the original user's complete build flags are not separately logged.

This recipe correction does not rerun compilation or runtime tests. No requested feature omissions are recorded.

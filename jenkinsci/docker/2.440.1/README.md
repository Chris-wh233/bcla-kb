# Jenkins 2.440.1 Alpine LoongArch64

This recipe builds `jenkins:2.440.1-alpine-loongarch64` for native `linux/loong64` from the official Jenkins Docker repository.

## Source and inputs

- Repository: https://github.com/jenkinsci/docker
- Release tag: `2.440.1`
- Resolved commit: `6fda6fcea4b9cb1696f485ab2b31cbbfa33fe374`
- Upstream Dockerfile: `17/alpine/hotspot/Dockerfile` (SHA-256 `c123e6719c35ed966ac71d13ab2c41c77742dd4bbe45bfcfe3b57f0d01447e6f`)
- Base: `alpine:latest`; the verified LoongArch build used Alpine 3.24.4 from `lcr.loongnix.cn/library/alpine:latest`, image ID `sha256:dc0a951b7a78247d8b1f784390eaa54cc3b8180b2fc44b6105515fe971ee34d3`.

The build context also needs the upstream support scripts from the source checkout and these two Java archives:

- `artifacts/jenkins-2.440.1.war` from the [official Jenkins WAR repository](https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/2.440.1/jenkins-war-2.440.1.war), SHA-256 `0a4dee3276867329745bc9d253dad8565fab00b4c2f06e1a22d492d6d464495d`. Its published checksum is available at `https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/2.440.1/jenkins-war-2.440.1.war.sha256`.
- `artifacts/jenkins-plugin-manager-2.12.15.jar` from the [official Plugin Installation Manager release](https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.15/jenkins-plugin-manager-2.12.15.jar), SHA-256 `2689ad36cf8eed09c6ce496dfc787dbbec7347b1503275e2b1315b65a7fe8e5a`. The release asset has no SHA-256 sidecar; the adapted Dockerfile checks this recorded hash.

The adapted Dockerfile installs `openjdk17-loongarch-jre-headless` and `openjdk17-loongarch-jre` from Alpine. Both were version `17.0.17_p10-r0` in the verified build, and `java` reported the OpenJDK 64-Bit Server VM.

## Prepare and build

Set `WORKSPACE` to a writable directory and `BCLA_RECIPE_DIR` to this recipe directory. Run on a LoongArch64 Docker host:

```sh
git clone https://github.com/jenkinsci/docker "$WORKSPACE/jenkins-docker"
cd "$WORKSPACE/jenkins-docker"
git checkout --detach 6fda6fcea4b9cb1696f485ab2b31cbbfa33fe374
mkdir -p artifacts
curl -fL https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/2.440.1/jenkins-war-2.440.1.war -o artifacts/jenkins-2.440.1.war
curl -fL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/2.440.1/jenkins-war-2.440.1.war.sha256 -o artifacts/jenkins-2.440.1.war.sha256
WAR_SHA=$(awk '{print $1}' artifacts/jenkins-2.440.1.war.sha256)
printf '%s  %s\n' "$WAR_SHA" artifacts/jenkins-2.440.1.war | sha256sum -c
curl -fL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.15/jenkins-plugin-manager-2.12.15.jar -o artifacts/jenkins-plugin-manager-2.12.15.jar
printf '%s  %s\n' 2689ad36cf8eed09c6ce496dfc787dbbec7347b1503275e2b1315b65a7fe8e5a artifacts/jenkins-plugin-manager-2.12.15.jar | sha256sum -c
git apply "$BCLA_RECIPE_DIR/patches/loongarch.patch"
docker pull --platform=linux/loong64 lcr.loongnix.cn/library/alpine:latest
docker tag lcr.loongnix.cn/library/alpine:latest alpine:latest
docker build --pull=false --network=host --platform=linux/loong64 \
  --build-arg JENKINS_VERSION=2.440.1 \
  --build-arg JENKINS_SHA=0a4dee3276867329745bc9d253dad8565fab00b4c2f06e1a22d492d6d464495d \
  --build-arg COMMIT_SHA=6fda6fcea4b9cb1696f485ab2b31cbbfa33fe374 \
  -f 17/alpine/hotspot/Dockerfile \
  -t jenkins:2.440.1-alpine-loongarch64 .
```

`alpine:latest` is a mutable tag. The recorded build resolved it to the Alpine image above; later builds may resolve it to a newer release. The Dockerfile build context must be the Jenkins repository root.

## Verified result

The final image ID was `sha256:48dac3787846e7b1ad61534f70763d98c8442d93a9c8fe40fdda783be3820405`, with platform `linux/loong64`. Image inspection and a container check confirmed Alpine 3.24.4, both requested JRE packages, OpenJDK 17.0.17 Server VM, and Jenkins 2.440.1. A startup smoke test reached `/login` with HTTP 200 and the page title `Sign in [Jenkins]`. The image was built and tested locally; it was not pushed.

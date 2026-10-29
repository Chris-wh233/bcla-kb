# Jenkins 2.583 Alpine LoongArch64

This recipe builds jenkins:2.583-alpine-loongarch64 for native linux/loong64 from the official Jenkins Docker repository.

## Source and inputs

- Repository: https://github.com/jenkinsci/docker
- Release tag: 2.583
- Resolved commit: 42ea8b6681fac34a1a8b447644728e70b3eeaae0
- Upstream Dockerfile: alpine/hotspot/Dockerfile
- Accepted adapted Dockerfile: Dockerfile.alpine-loongarch64
- Base image: lcr.loongnix.cn/library/alpine:latest in both stages. At the verified build it resolved to Alpine 3.24.3, image ID sha256:5f5123bece66cb4de60b6d4bbb31c6b03bfe43d930d02381dfd67b6ad5e9bc7a and registry digest sha256:6fd5d99e0bd67d9f59333d6c60b893989d96164ccc0a0c9ca61b38631f24aa49. The tag is mutable.

The build context needs these files:

- jenkins.io-2026.key from the checked out Jenkins Docker source.
- artifacts/jenkins-2.583.war, downloaded from https://mirrors.xmission.com/jenkins/war/2.583/jenkins.war. Its accepted SHA-256 is 2eb6df14b0c1cda704ad88800395a071856774cadc4f64d9527d8ec8380b41c6.
- artifacts/jenkins-2.583.war.sha256 and artifacts/jenkins-2.583.war.asc from the official Jenkins 2.583 WAR sidecars at https://get.jenkins.io/war/2.583/.
- artifacts/jenkins-plugin-manager-2.15.0.jar and its .sha256 sidecar from the official GitHub release at https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.15.0/. The accepted JAR SHA-256 is a86853ec2e2933f37a4b471ba65099b61e03c87a80c2ef8fe2315eb135672d43.

The adapted Dockerfile verifies the WAR checksum and Jenkins GPG signature and checks the plugin-manager JAR checksum during the image build.

## Prepare and build

Set WORKSPACE to a writable parent directory and BCLA_RECIPE_DIR to this recipe directory. Then run:

    git clone https://github.com/jenkinsci/docker "$WORKSPACE/jenkins-docker"
    cd "$WORKSPACE/jenkins-docker"
    git checkout --detach 42ea8b6681fac34a1a8b447644728e70b3eeaae0
    mkdir -p artifacts
    curl -fL https://mirrors.xmission.com/jenkins/war/2.583/jenkins.war -o artifacts/jenkins-2.583.war
    curl -fL https://get.jenkins.io/war/2.583/jenkins.war.sha256 -o artifacts/jenkins-2.583.war.sha256
    curl -fL https://get.jenkins.io/war/2.583/jenkins.war.asc -o artifacts/jenkins-2.583.war.asc
    curl -fL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.15.0/jenkins-plugin-manager-2.15.0.jar -o artifacts/jenkins-plugin-manager-2.15.0.jar
    curl -fL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.15.0/jenkins-plugin-manager-2.15.0.jar.sha256 -o artifacts/jenkins-plugin-manager-2.15.0.jar.sha256
    cp "$BCLA_RECIPE_DIR/Dockerfile.alpine-loongarch64" alpine/hotspot/Dockerfile
    docker build --network=host -f alpine/hotspot/Dockerfile -t jenkins:2.583-alpine-loongarch64 --build-arg JENKINS_VERSION=2.583 --build-arg COMMIT_SHA=42ea8b6681fac34a1a8b447644728e70b3eeaae0 .

The verified build ran from the Jenkins repository root on a LoongArch64 Docker daemon using the Docker legacy builder and host networking. No proxy setting was part of the target image.

## Verified result

The immutable image ID was sha256:58592cde8e4493b9b20344c2abc97907d61073532caeca9a2cd780f718a18f80, with platform linux/loong64. The image installs openjdk25-loongarch-jre-headless 25.0.1_p8-r1 as required and the matching openjdk25-loongarch-jre package; both were present at that version. The JVM reported OpenJDK 64-Bit Server VM, and Jenkins reported version 2.583.

The final smoke test used a container with networking disabled, waited for /login to return HTTP 200, and confirmed the log message “Jenkins is fully up and running”. The image was built and tested locally; it was not pushed.

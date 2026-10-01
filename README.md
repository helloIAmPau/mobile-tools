# Mobile tools

A reusable Linux x86_64 development image containing Node.js 24.21.0/npm 11, Java 17, Android SDK/API 36, build-tools 35/36, NDK 27.1, CMake, the Android emulator, and Maestro 2.11.0.

The image contains no application source, npm dependencies, or application startup script. Consumers provide their own source mounts and command. Native Android emulation requires `/dev/kvm` on the Docker host; this image cannot build or run iOS applications.

## Consume the image

Images are published at `ghcr.io/helloiampau/mobile-tools`, with `latest` and `sha-<full-commit>` tags. Pin the published digest in a project's Compose file to make upgrades deliberate:

```yaml
services:
  mobile-tools:
    image: ghcr.io/helloiampau/mobile-tools@sha256:<published-digest>
    platform: linux/amd64
    init: true
    devices:
      - /dev/kvm:/dev/kvm
    volumes:
      - ./data/mobile-tools:/state
    command: [bash, -c, "node --version && java -version"]
```

`HOME`, `GRADLE_USER_HOME`, and `ANDROID_AVD_HOME` are under `/state`, which consumers can persist with a host bind mount. `ANDROID_HOME` is `/opt/android`; SDK executables and Maestro are on `PATH`. A plain `bash` or `sh` command preserves that environment; a login shell may replace `PATH`.

GHCR initially creates packages as private, even for a public source repository. Package visibility must be public for anonymous pulls; otherwise consumers need registry credentials with package read permission. GitHub Actions publishes with its own scoped `GITHUB_TOKEN`, without a personal access token in repository secrets.

## Build and verify

Docker with KVM access and Node/npm to invoke scripts are required. No npm installation is needed: this repository has no JavaScript package dependencies.

```sh
npm test
npm run build
```

`npm test` builds the test image, compiles and signs a disposable native APK using the SDK, boots Android 16 on a headless Pixel 6 emulator, installs the APK, and verifies its screen on launch and relaunch with Maestro. All fixture files stay flat in `tests/e2e/`. The fixture and its signing key are never included in the distribution image. Missing KVM or failed native tests fail the command.

The first build downloads several gigabytes of SDK/emulator tooling. GitHub Actions runs the complete suite before publishing on `main`; pull requests run the same checks without publication. Images carry the source-repository OCI label. Application-level behavior must also be tested by each consuming project.

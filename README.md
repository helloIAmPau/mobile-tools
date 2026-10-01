# Mobile tools

A reusable Linux x86_64 development image containing Node.js 24.21.0/npm 11, Java 17, Android SDK/API 36, build-tools 35/36, NDK 27.1, CMake, the Android emulator, and Maestro 2.11.0.

The image includes a reusable Expo Android development lifecycle (`mobile-develop`), with no application source or bundled app dependencies. Consumers select an npm workspace and provide source mounts. Native Android emulation requires `/dev/kvm` on the Docker host; this image cannot build or run iOS applications.

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
    environment:
      MOBILE_WORKSPACE: packages/mobile
      REACT_NATIVE_PACKAGER_HOSTNAME: localhost
      EXPO_NO_TELEMETRY: "1"
      EXPO_NO_DEV_MENU: "1"
    volumes:
      - .:/project:ro
      - ./packages:/source/packages
      - ./data/mobile-tools:/state
```

`MOBILE_WORKSPACE` is required: the app's path relative to `/source`, such as `packages/mobile` or `workspaces/@example/app`. Mount every root npm workspace at the matching path under `/source`. The root `package.json` and `package-lock.json` are linked from `/project`; directory mounts keep atomic manifest replacements visible, while installed `node_modules` remain isolated inside the container.

The selected workspace must provide:

- `app.json` with `expo.android.package` and a string `expo.scheme`.
- An npm `develop` script that starts Expo's development-client Metro server on port 8081; the lifecycle adds `--localhost`.
- An npm `android` script that generates, builds and installs the development client without starting another Metro server. For example: `expo prebuild --platform android --no-install --clean && expo run:android --no-bundler`.

The default command installs with `npm ci`, boots a headless Android emulator, starts Metro, builds/installs the app and opens its development-client URL. Source changes use Metro Fast Refresh. Edits to `app.json`, root/workspace manifests or the lockfile trigger native rebuild/reinstall; dependency manifest changes also reinstall npm packages and restart Metro. Workspace manifests are discovered from the root npm workspace patterns, independent of package names or directory depth. This lifecycle currently supports static `app.json`, not dynamic Expo configuration files.

Wait for `Mobile ready` (and `/state/mobile-ready`) before running app E2E tests. A native build failure clears readiness; edit the configuration or dependency manifests to retry. Container shutdown stops the build, Metro and emulator. Override the command with `bash` for manual tooling use.

`HOME`, `GRADLE_USER_HOME`, and `ANDROID_AVD_HOME` are under `/state`, which consumers can persist with a host bind mount. `ANDROID_HOME` is `/opt/android`; SDK executables and Maestro are on `PATH`. A plain `bash` or `sh` command preserves that environment; a login shell may replace `PATH`.

GHCR initially creates packages as private, even for a public source repository. Package visibility must be public for anonymous pulls; otherwise consumers need registry credentials with package read permission. GitHub Actions publishes with its own scoped `GITHUB_TOKEN`, without a personal access token in repository secrets.

## Build and verify

Docker with KVM access and Node/npm to invoke scripts are required. No npm installation is needed: this repository has no JavaScript package dependencies.

```sh
npm test
npm run build
```

`npm test` builds the test image, verifies that the packaged lifecycle rejects a missing workspace selection, compiles and signs a disposable native APK using the SDK, boots Android 16 on a headless Pixel 6 emulator, installs the APK, and verifies its screen on launch and relaunch with Maestro. All fixture files stay flat in `tests/e2e/`. The fixture and its signing key are never included in the distribution image. Missing KVM or failed native tests fail the command.

The first build downloads several gigabytes of SDK/emulator tooling. GitHub Actions runs the complete suite before publishing on `main`; pull requests run the same checks without publication. Images carry the source-repository OCI label. Application-level behavior must also be tested by each consuming project. Lifecycle changes require the consuming project's complete development stack and E2E suite, covering app launch, Fast Refresh, configuration rebuilds and dependency-manifest rebuilds; the native fixture alone does not validate the Expo lifecycle.

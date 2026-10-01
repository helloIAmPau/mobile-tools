# Mobile tools development

- Keep this image application-independent: no Hybrid source, bundled application dependencies, or hardcoded app identifiers. The image owns the generic Expo Android lifecycle through mobile-develop; consumers select MOBILE_WORKSPACE and provide source, root manifests and npm develop/android scripts.
- Use Node 24/npm 11 on Debian for Android's glibc requirement. Pin the Node image and downloaded tool versions; validate download checksums when supplied upstream.
- Target Linux x86_64 with Docker-host KVM. Do not imply this Linux image supports native iOS builds.
- Keep persistent runtime paths under `/state`; consumers choose bind mounts. Do not declare Docker volumes or publish ports in the image.
- `npm test` always runs the entire real Android E2E suite. Keep fixtures and tests flat in `tests/e2e/`. The test stage compiles/installs a native app and verifies launch/relaunch through Maestro; never replace that with mocked or version-only checks.
- For lifecycle changes, also run a consuming Expo project's complete development stack and E2E suite, covering native launch, source refresh, config rebuilds and dependency-manifest reinstall. The SDK fixture alone does not validate the Expo lifecycle.
- Publish the runtime stage only after tests pass. Use GitHub Actions' `GITHUB_TOKEN` with package write permission. Publish commit-addressed tags and update latest on main. Never put registry credentials into the image or source.
- Before a new feature, preserve existing work, check out main, update it with `git pull --ff-only origin main`, then create an issue-named feature branch. Keep issue status and approval history on GitHub, not here.
- Authored files and directories in this development environment belong to `node:users`. Generated artifacts may be excluded.

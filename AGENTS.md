# Mobile tools development

- Keep this image application-independent: no Hybrid source, package installation, app identifiers, or app startup logic. Consumers own their application lifecycle.
- Use Node 24/npm 11 on Debian for Android's glibc requirement. Pin the Node image and downloaded tool versions; validate download checksums when supplied upstream.
- Target Linux x86_64 with Docker-host KVM. Do not imply this Linux image supports native iOS builds.
- Keep persistent runtime paths under `/state`; consumers choose bind mounts. Do not declare Docker volumes or publish ports in the image.
- `npm test` always runs the entire real Android E2E suite. Keep fixtures and tests flat in `tests/e2e/`. The test stage compiles/installs a native app and verifies launch/relaunch through Maestro; never replace that with mocked or version-only checks.
- Publish the runtime stage only after tests pass. Use GitHub Actions' `GITHUB_TOKEN` with package write permission. Publish commit-addressed tags and update latest on main. Never put registry credentials into the image or source.
- Before a new feature, preserve existing work, check out main, update it with `git pull --ff-only origin main`, then create an issue-named feature branch. Keep issue status and approval history on GitHub, not here.
- Authored files and directories in this development environment belong to `node:users`. Generated artifacts may be excluded.

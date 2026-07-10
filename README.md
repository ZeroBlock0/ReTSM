# ReTSM

ReTeamSpeakManager

## Prerequisites

Ensure you have the following installed:
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+ recommended)
2. [Rust](https://www.rust-lang.org/tools/install)
3. `flutter_rust_bridge_codegen` installed globally. Keep it aligned with the generated bridge version in this repo:
   ```bash
   cargo install 'flutter_rust_bridge_codegen@^2.12.0'
   ```
4. Windows packaging requires stable [Inno Setup 6.7](https://jrsoftware.org/isdl.php). Install it in the default directory or add `ISCC.exe` to `PATH`. The build script also recognizes Inno Setup 7, but the current 7.x release is beta and is not required.

## Setup

Since this project uses `flutter_rust_bridge` to connect Dart UI with Rust backend logic, run the code generator whenever you change files under `rust/src/api/` or otherwise update the bridge contract.

1. Install Dart dependencies:
   ```bash
   flutter pub get
   ```

2. Generate the Rust-Dart bridge bindings:
   ```bash
   flutter_rust_bridge_codegen generate
   ```

3. Run the application (Desktop):
   ```bash
   flutter run -d windows # Or macos/linux
   ```

## Windows Release Build

The repository uses the same `build.ps1` packaging flow locally and in GitHub
Actions. It builds the Flutter application, creates a portable ZIP, compiles an
Inno Setup installer, and generates SHA-256 checksums.

1. Install the prerequisites above.
2. Build and package the application:
   ```powershell
   .\build.ps1
   ```
3. Collect the files from `dist/`:
   - `ReTSM-Windows-x64-v1.2.3.zip`: portable, no installation required.
   - `ReTSM-Setup-v1.2.3.exe`: per-user Inno Setup installer; administrator access is not required.
   - `SHA256SUMS.txt`: SHA-256 checksums for both packages.

Use `build.ps1 -SkipFlutterBuild` to repackage an existing Windows Release
build without compiling Flutter again.

The installer is currently unsigned, so Windows SmartScreen can warn on first
run. For broad public distribution, add Authenticode signing to the workflow
after obtaining a trusted code-signing certificate or signing service.

## Automated Releases

Normal pushes to `master` do not create a release and do not require a version
change. Use the regular Git workflow while developing:

```bash
git add .
git commit -m "feat: describe the change"
git push origin master
```

GitHub Actions publishes both the Windows x64 portable ZIP and the Inno Setup
installer whenever a SemVer tag is pushed. It also publishes
`SHA256SUMS.txt`. The tag version must match the version in `pubspec.yaml`
(build metadata such as `+1` is ignored when matching).

Choose the next version according to SemVer:

- Bug fix: `1.0.0` -> `1.0.1` (patch).
- Backward-compatible feature: `1.0.1` -> `1.1.0` (minor).
- Breaking change: `1.1.0` -> `2.0.0` (major).
- Pre-release: `1.1.0-beta.1`, `1.1.0-rc.1`, and so on.
- Increase the `+N` build number for every release. The Git tag never includes
  this build metadata.

- Stable release: `v1.2.3`
- Pre-release: `v1.2.3-beta.1`

Prepare and publish a release from `master`:

```bash
# First update pubspec.yaml to: version: 1.2.3+2
git add pubspec.yaml
git commit -m "chore: release v1.2.3"
git push origin master

git tag -a v1.2.3 -m "ReTSM v1.2.3"
git push origin v1.2.3
```

Tags that are not valid SemVer, do not match `pubspec.yaml`, or do not point to
a commit on `master` are rejected by the release workflow. Pre-release tags are
published as GitHub pre-releases; stable tags are marked as the latest release.
Do not move or reuse a tag after its Release has been published. Fix the issue,
increment the patch version and build number, and publish a new tag instead.

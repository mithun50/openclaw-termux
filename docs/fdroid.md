# Publishing to F-Droid

Status: **not yet submittable to the main F-Droid repo.** One hard blocker remains
(building the PRoot stack from source). Everything else is either done or is
paperwork. This document records exactly what the policy requires, what has been
done, and what is left.

Policy references, checked 2026-09-14:

- <https://f-droid.org/en/docs/Inclusion_Policy/>
- <https://f-droid.org/en/docs/Build_Metadata_Reference/>
- <https://f-droid.org/en/docs/Anti-Features/>

## Where we stand

| Requirement | Status |
|---|---|
| FLOSS licence | **OK.** MIT, plus MIT/BSD/Apache dependencies |
| No proprietary SDKs (GMS, Firebase, Crashlytics, ad/tracking) | **OK.** None present |
| No analytics or telemetry | **OK.** None |
| Unique application ID | **OK.** `com.nxg.openclawproot` |
| Actively maintained | **OK** |
| Useful, not a demo, has unique value | **OK.** No other F-Droid app runs the OpenClaw gateway on Android |
| Fastlane metadata present before inclusion | **Done** (`fastlane/metadata/android/en-US/`) |
| Release builds not signed with a debug key | **Done.** `-Pfdroid` leaves release unsigned |
| Explicit opt-in consent before downloading executables | **Done.** Setup wizard consent notice |
| Anti-features declared | **Documented below**, to be set in the fdroiddata recipe |
| **All native binaries built from source** | **BLOCKER.** See below |

## The blocker: PRoot binaries

The inclusion policy is explicit:

> All binary dependencies including JAR files must originate either from source
> compilation or Debian repository downloads. Prebuilt binaries should only come
> from authorized trusted sources.

The permitted prebuilt sources are Debian `main`, a short list of trusted Maven
repositories, the Android and Flutter SDKs, Hermes, and PyPI / Nix / Rust / Go /
Node.js toolchains. **The Termux apt repository is not on that list**, and
`scripts/fetch-proot-binaries.sh` pulls four `.so` files from
`packages.termux.dev` into `flutter_app/android/app/src/main/jniLibs/`:

| File | Upstream | Licence |
|---|---|---|
| `libproot.so` | <https://github.com/termux/proot> | GPL-2.0 |
| `libprootloader.so`, `libprootloader32.so` | same, built as `loader` | GPL-2.0 |
| `libtalloc.so` | <https://gitlab.com/samba-team/samba> (`lib/talloc`) | LGPL-3.0-or-later |
| `libandroid-shmem.so` | <https://github.com/termux/libandroid-shmem> | BSD-2-Clause |

All four are FLOSS, so this is a build-process problem, not a licensing one. Note
Debian's own `proot` package will not work: Android needs Termux's Bionic patches.

### What has to happen

The fdroiddata recipe must compile these with the NDK during the build, roughly:

1. `srclibs` entries for `proot`, `libandroid-shmem` and `talloc` pinned to
   specific commits or tags.
2. A `build:` step that cross-compiles each for `arm64-v8a`, `armeabi-v7a` and
   `x86_64` using the NDK toolchain, applying Termux's Android patches.
3. Copy the results into `jniLibs/<abi>/lib*.so` with the same names the app
   expects, then run the Flutter build.
4. `scanignore` for the Flutter SDK only, which the policy explicitly permits.

Termux's own build scripts for these packages are the reference. This is real
work, likely the largest remaining task, and it should be validated with
`fdroid build` locally before opening a merge request.

Until it is done, the realistic options are:

- **Ship a self-hosted F-Droid repository.** Fully allowed, no policy review, and
  users add it as a custom repo. The APKs we already build would work as-is.
- Submit to the main repo only after the from-source build works.

## Runtime downloads and user consent

The policy also says:

> Applications must not download additional executable binary files (e.g.
> add-ons, auto-updates, etc.) without explicit user consent. Consent means it
> needs to be opt-in (it must not be harder to decline than to accept or
> presented in a way users are likely to press accept without reading) and
> structured in a way that clearly explains to users that they're choosing to
> bypass F-Droid's checks if they activate it.

This app downloads an Ubuntu rootfs, the Node.js runtime, and the `openclaw` npm
package, all executable, all at runtime. That is inherent to what it does, and
there is precedent: Termux and proot-distro do the same and are in the main repo.

The setup wizard now states plainly, before anything is downloaded, that the app
will fetch and run executables that F-Droid has not reviewed, lists exactly what
is fetched and from where, and requires an explicit tap to proceed. Setup cannot
start without it.

## Anti-features to declare

To be set in the fdroiddata recipe:

- **NonFreeNet.** The app's primary use is talking to hosted AI providers
  (Anthropic, OpenAI, Google Gemini and others), which are proprietary network
  services. Ollama support means the app is usable with no proprietary service at
  all, which is worth stating in the description, but the default path is a hosted
  provider.
- **NonFreeDep.** Worth discussing with reviewers: the runtime pulls the
  `openclaw` npm package and its dependency tree, which is not audited by F-Droid
  or by us.

Declare these honestly. Undisclosed anti-features are grounds for rejection.

## Things reviewers will ask about

- `MANAGE_EXTERNAL_STORAGE` is declared in the manifest. It is never requested
  automatically and is opt-in from Settings, needed only for proot to reach
  `/sdcard`. Be ready to justify it, or move it to a separate flavour.
- `android:usesCleartextTraffic="true"` is needed for the loopback gateway on
  `127.0.0.1`. A `network_security_config.xml` scoped to localhost would be a
  cleaner answer and is worth doing before submission.
- The node feature exposes camera, location, screen recording and sensors to the
  AI. It is off by default and documented in the privacy policy.
- `google_fonts` fetches font files from Google at runtime. This is a network
  dependency on a Google service for a non-functional asset. Bundling the font in
  `assets/fonts/` and dropping the dependency would remove it. Recommended before
  submission.

## Submission steps, once the blocker is cleared

1. Verify the build locally with `fdroid build --verbose com.nxg.openclawproot`.
2. Fork <https://gitlab.com/fdroid/fdroiddata>, add
   `metadata/com.nxg.openclawproot.yml`, use the draft below as a starting point.
3. Open a merge request and expect review iterations.

## Draft recipe

Not yet valid: the `build` steps for the PRoot stack are the part that needs
writing and testing.

```yaml
Categories:
  - Development
  - System
License: MIT
AuthorName: Mithun Gowda B
AuthorEmail: mithungowda.b7411@gmail.com
SourceCode: https://github.com/mithun50/openclaw-termux
IssueTracker: https://github.com/mithun50/openclaw-termux/issues
Changelog: https://github.com/mithun50/openclaw-termux/blob/main/CHANGELOG.md

AntiFeatures:
  - NonFreeNet

RepoType: git
Repo: https://github.com/mithun50/openclaw-termux.git

Builds:
  - versionName: 2026.9.14
    versionCode: 20
    commit: v2026.9.14
    subdir: flutter_app/android/app
    sudo:
      - apt-get update
      - apt-get install -y clang make
    init:
      - git -C $$flutter$$ config --global --add safe.directory $$flutter$$
    gradle:
      - yes
    srclibs:
      - flutter@stable
      - proot@<pinned-tag>
      - libandroid-shmem@<pinned-commit>
      - talloc@<pinned-tag>
    prebuild:
      # TODO: cross-compile proot, loader, libtalloc and libandroid-shmem with
      # the NDK for each ABI and place them in
      # flutter_app/android/app/src/main/jniLibs/<abi>/
      - echo "not implemented yet"
    build:
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter pub get
      - $$flutter$$/bin/flutter build apk --release -Pfdroid
    ndk: r27
    output: build/app/outputs/flutter-apk/app-release.apk
    scanignore:
      - flutter_app/android/gradle/wrapper/gradle-wrapper.properties

AutoUpdateMode: None
UpdateCheckMode: Tags
CurrentVersion: 2026.9.14
CurrentVersionCode: 20
```

## Self-hosted repository alternative

If the from-source work is deferred, a self-hosted repo is a legitimate way to
reach F-Droid users now:

```bash
pip install fdroidserver
mkdir -p fdroid-repo && cd fdroid-repo
fdroid init
cp /path/to/OpenClaw-v2026.9.14-universal.apk repo/
fdroid update --create-metadata
```

Serve the directory over HTTPS and publish the repo URL and fingerprint. Users
add it in the F-Droid client. This does not require passing the inclusion policy,
but it also does not give the trust guarantees of the main repo, so say so
plainly when advertising it.

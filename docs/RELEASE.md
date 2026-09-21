# Release checklist

How a MacBroom version goes from source to a GitHub Release.

## Option A — GitHub Actions (recommended)

[`.github/workflows/release-macos.yml`](../.github/workflows/release-macos.yml) — adapted
from [jejezz/application-release-templates](https://github.com/jejezz/application-release-templates)'
`desktop/` template — builds, signs, notarizes and publishes for you:

```bash
git tag -a v1.0.2 -m "MacBroom 1.0.2"
git push --follow-tags
```

Pushing a `v1.2.3`-style tag (needs the full `major.minor.patch`, matching the
`v*.*.*` trigger) runs `build-macos`, which builds the app, signs it with the
Developer ID Application certificate (Hardened Runtime + `Release.entitlements`),
packages it into a DMG with `create-dmg`, and notarizes + staples it with
`notarytool`. The `release` job then downloads that DMG and publishes it as a
**public** GitHub Release (`gh release create ... --generate-notes`) — no draft
step, and release notes are auto-generated from merged PRs/commits since the
last tag. Edit them afterward with `gh release edit v1.2.3 --notes-file notes.md`
if you want the curated write-up from the template in step 4 below.

Required secrets (already registered in this repo): `MACOS_CERTIFICATE_P12_BASE64`,
`MACOS_CERTIFICATE_PASSWORD`, `MACOS_KEYCHAIN_PASSWORD`, `APPLE_ID`,
`APPLE_ID_PASSWORD` (an app-specific password from appleid.apple.com, not the
account password), `APPLE_TEAM_ID`.

Because the app is now notarized, the "not notarized" install caveat in the release
notes template below (step 4) and the ad-hoc quarantine/Full-Disk-Access caveat no
longer apply to CI-built releases — they're still accurate for ad-hoc local builds
(Option B without `SIGNING_IDENTITY`).

## Option B — local build

## 1. Bump the version

Edit `pubspec.yaml` — the build number (`+N`) must increase every time:

```yaml
version: 1.0.2+3
```

```bash
git commit -am "Bump version to 1.0.2"
```

## 2. Build the package

```bash
./scripts/release.sh
```

Output in `dist/`: `MacBroom-<version>.dmg`, `MacBroom-<version>.zip` and their SHA-256 hashes
(printed at the end — copy them into the release notes).

Without `SIGNING_IDENTITY` the app is ad-hoc signed; see `README.md` for the
Developer ID + notarization variant.

## 3. Tag and push

```bash
git tag -a v1.0.2 -m "MacBroom 1.0.2"
git push --follow-tags
```

`--follow-tags` pushes the commit **and** the tag. `gh release create` fails if the tag
only exists locally.

## 4. Create the GitHub Release

```bash
gh release create v1.0.2 dist/MacBroom-1.0.2.dmg dist/MacBroom-1.0.2.zip \
    --title "MacBroom 1.0.2" --notes-file notes.md
```

Release notes template:

```markdown
## What's new
- …

## Install
1. Download `MacBroom-1.0.2.dmg`, open it and drag **MacBroom** to **Applications**.
2. Not notarized: on first launch right-click MacBroom.app → Open → Open, or
   `xattr -d com.apple.quarantine /Applications/MacBroom.app`
3. Grant Full Disk Access when the banner appears (*Show me how* walks you through it).

> Ad-hoc signed builds are a new identity to macOS on every release — Full Disk Access
> must be granted again after upgrading.

## Checksums (SHA-256)
<paste from release.sh>
```

## 5. Verify

```bash
gh release view v1.0.2
```

Open the DMG on a clean account or another Mac and launch the app once.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `gh release create` → tag not found | Tag not pushed: `git push origin v1.0.2` |
| Full Disk Access shows "off" after upgrading | Expected with ad-hoc signing; grant it again |
| App won't open, "damaged" | Quarantine flag: `xattr -d com.apple.quarantine …` or right-click → Open |

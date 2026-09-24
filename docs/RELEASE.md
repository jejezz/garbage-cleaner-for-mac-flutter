# Release checklist

How a MacBroom version goes from source to a GitHub Release.

## Option A — GitHub Actions (recommended)

[`.github/workflows/release-macos.yml`](../.github/workflows/release-macos.yml) runs
`scripts/release.sh` on a `macos-26` runner and does steps 2-4 below for you:

```bash
git tag -a v1.0.2 -m "MacBroom 1.0.2"
git push --follow-tags
```

Pushing a `v*` tag builds the ad-hoc signed `.dmg`/`.zip`, uploads them as a workflow
artifact, and opens a **draft** GitHub Release with the checksums already filled in.
Open the draft, fill in "What's new" (see the template in step 4 below), and publish it.

You can also run it without tagging — Actions tab → **Release · macOS** → **Run
workflow** — to sanity-check a build; that mode only uploads the artifact, no tag or
release is created. Its `build_number` input overrides the one in `pubspec.yaml` (useful
when you need a throwaway build without bumping the real version).

The workflow has no Apple Developer Program secrets configured, so it always produces
an ad-hoc signed build, same as running `scripts/release.sh` locally with no
`SIGNING_IDENTITY`. Wiring in Developer ID signing + notarization would mean: importing
a `.p12` certificate into a temporary keychain, exposing it as `SIGNING_IDENTITY`, and
calling `xcrun notarytool submit` with an App Store Connect API key or app-specific
password instead of a local `--keychain-profile` (`scripts/release.sh` already accepts
`SIGNING_IDENTITY`/`NOTARY_PROFILE`, so the workflow only needs the keychain setup step
added — do this once an Apple Developer Program account exists).

## Option B — local build

## 1. Bump the version

```bash
scripts/bump-version.sh patch   # 1.0.3+4 -> 1.0.4+5, commits "chore(release): v1.0.4"
```

`minor`, `major`, `build` or an explicit `1.1.0-rc.1` work too. The build number
(`+N`) always goes up by one and never resets. The script doesn't tag — tag the
merge commit on `main` after the PR lands.

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

# version-bump-workflow

Reusable GitHub Actions for tag-based semver releases. The version lives only in git tags:
each release reads the latest `<prefix>X.Y.Z` tag on the remote, bumps it, and whatever
creates the release (`gh release create`, `softprops/action-gh-release`, ...) creates the
new tag.

| Action                                                    | What it does                                                    |
| --------------------------------------------------------- | --------------------------------------------------------------- |
| `wuguishifu/version-bump-workflow@v1`                     | Computes the next version from the latest tag                   |
| `wuguishifu/version-bump-workflow/set-package-version@v1` | Writes a version into `package.json`, preserving its formatting |
| `wuguishifu/version-bump-workflow/docker-image@v1`        | Builds `<registry>/<image>:<version>-<sha>` and `:latest` refs  |

## Version bump

```yaml
- uses: actions/checkout@v4

- name: bump version
  id: version
  uses: wuguishifu/version-bump-workflow@v1
  with:
    bump-type: ${{ inputs.version-bump-type }}
```

The repo must be checked out first (tags are read with `git ls-remote origin`, so a
shallow checkout is fine). The job that creates the release needs `contents: write`.

| Input             | Default  | Description                                                                             |
| ----------------- | -------- | --------------------------------------------------------------------------------------- |
| `bump-type`       | `patch`  | `major`, `minor` or `patch`                                                             |
| `tag-prefix`      | `v`      | Prefix in front of `X.Y.Z`, e.g. `topaz-v` for per-app tags in a monorepo. May be empty |
| `initial-version` | `0.0.0`  | Version to bump from when no matching tag exists, so the first `major` is `1.0.0`       |
| `remote`          | `origin` | Git remote to read tags from                                                            |

| Output             | Example                              |
| ------------------ | ------------------------------------ |
| `version`          | `1.2.3`                              |
| `tag`              | `v1.2.3`                             |
| `previous-version` | `1.2.2` (empty if there was no tag)  |
| `previous-tag`     | `v1.2.2` (empty if there was no tag) |

Only tags that are exactly `<prefix>X.Y.Z` count: pre-release tags like `v2.0.0-beta` and
tags from other prefixes like `topaz-v1.0.0` (when the prefix is `v`) are ignored.

## Set package version

```yaml
- uses: wuguishifu/version-bump-workflow/set-package-version@v1
  with:
    version: ${{ needs.version.outputs.version }}
    path: package.json # default
```

Fails if the file has no top-level `"version"` field.

## Docker image

```yaml
- name: docker image
  id: docker
  uses: wuguishifu/version-bump-workflow/docker-image@v1
  with:
    version: ${{ steps.version.outputs.tag }}
    image: wuguishifu/universe/topaz
    registry: ghcr.io # default

- run: |
    docker build -t ${{ steps.docker.outputs.image }} -t ${{ steps.docker.outputs.image-latest }} .
    docker push ${{ steps.docker.outputs.image }}
    docker push ${{ steps.docker.outputs.image-latest }}
```

Outputs `tag` (`topaz-v1.2.3-abcd1234`), `image` (`ghcr.io/wuguishifu/universe/topaz:topaz-v1.2.3-abcd1234`),
`image-latest` (`ghcr.io/wuguishifu/universe/topaz:latest`) and `image-name`
(`ghcr.io/wuguishifu/universe/topaz`). The image name is lowercased, since registries
reject uppercase and `github.repository` can contain it.

## Examples

### Single-package app with binaries (homework-downloader, gtools)

```yaml
jobs:
  version:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      tag: ${{ steps.version.outputs.tag }}
    steps:
      - uses: actions/checkout@v4
      - id: version
        uses: wuguishifu/version-bump-workflow@v1
        with:
          bump-type: ${{ inputs.version-bump-type }}

  build:
    needs: version
    steps:
      - uses: actions/checkout@v4
      - uses: wuguishifu/version-bump-workflow/set-package-version@v1
        with:
          version: ${{ needs.version.outputs.version }}
      # ... build

  release:
    needs: [version, build]
    permissions:
      contents: write
    steps:
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ needs.version.outputs.tag }}
```

### Monorepo with per-app tags (universe)

```yaml
- id: version
  uses: wuguishifu/version-bump-workflow@v1
  with:
    bump-type: ${{ inputs.version-bump-type }}
    tag-prefix: ${{ inputs.app }}-v

- id: docker
  uses: wuguishifu/version-bump-workflow/docker-image@v1
  with:
    version: ${{ steps.version.outputs.tag }}
    image: ${{ steps.config.outputs.registry_path }}

# ... build and push

- run: gh release create "${{ steps.version.outputs.tag }}" --target "$GITHUB_SHA" --latest=false
```

## Development

```sh
./test/test.sh
```

runs the scripts against a throwaway local remote. CI also runs the actions themselves.

### Releasing

Run the **Release** workflow from `main` (Actions → Release → Run workflow, or
`gh workflow run release.yml -f version-bump-type=minor`). It:

1. runs the tests,
2. computes the next version with this repo's own action (`uses: ./`),
3. creates the `vX.Y.Z` GitHub release with generated notes,
4. force-moves the `vN` major tag to that commit, so consumers on `@v1` pick it up.

The very first release should be a `major` bump, which gives `v1.0.0`. Breaking changes to
inputs or outputs need a `major` bump too, so consumers on the old `vN` aren't broken.

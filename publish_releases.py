#!/usr/bin/env python3
"""Publishes each packaged theme as a GitHub release and gathers download counts.

Every theme has one release, tagged theme-<Dir>, holding two files:

    <Dir>.zip          the packaged theme, ready to unzip into songo_themes/
    <Dir>-source.zip   its editable folder from themes_raw/, if it has one

so a theme's download link never changes:
    https://github.com/<repo>/releases/download/theme-<Dir>/<Dir>.zip

When a theme changes, its files in the release are replaced and the release's
title and notes updated to the new version. Old versions aren't kept.

A theme's download count is how many times <Dir>.zip has been downloaded,
across every version. GitHub's count starts again at 0 for a replaced file,
so the count of each replaced file is kept in the release notes and added on.
Source downloads aren't counted.

Changes are spotted by comparing each theme folder's git tree hash (or, for a
folder with uncommitted changes, a hash of its zip) with the one recorded in
the release notes, so unchanged themes aren't zipped at all.

Writes a JSON file for build_theme_site.py --releases, so the page links to the
release files and shows the counts:

    {"repo": "...", "themes": {"<Dir>": {"tag", "version", "download_url",
     "download_bytes", "source_url", "source_bytes", "downloads"}}}

Uses the GitHub CLI (gh), signed in, or with GH_TOKEN set as in GitHub Actions.

Usage (Python 3.8+, standard library only):
    python3 publish_releases.py --dry-run
    python3 publish_releases.py --repo Songo-Player/Songo-5-Themes --out releases.json
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import build_theme_site as site

DEFAULT_REPO = "Songo-Player/Songo-5-Themes"
TAG_PREFIX = "theme-"

# Release notes end with this, holding what's in the release and the
# download counts of the files it replaced.
META_RE = re.compile(r"<!-- songo-theme: (\{.*?\}) -->", re.S)

# GitHub limits how fast an account can create content, so writes are spaced
# out and a run updates at most --max-updates themes; the rest wait for the
# next run.
WRITE_PAUSE = 1.0


def warn(title: str, message: str) -> None:
    # GitHub Actions shows lines like this as warnings on the run.
    print(f"::warning title={title}::{message}", file=sys.stderr)


def fingerprint(folder: Path) -> "str | None":
    """The folder's git tree hash, when it's committed as it is; None if it
    has uncommitted changes or isn't in git."""
    def git(*args):
        return subprocess.run(["git", "-C", str(folder), *args], capture_output=True, text=True)
    status = git("status", "--porcelain", "--", ".")
    if status.returncode != 0 or status.stdout.strip():
        return None
    tree = git("rev-parse", "HEAD:./")
    return f"tree:{tree.stdout.strip()}" if tree.returncode == 0 else None


def zip_fingerprint(path: Path) -> str:
    return "zip:" + hashlib.sha256(path.read_bytes()).hexdigest()


class GitHub:
    def __init__(self, gh: str, repo: str, dry_run: bool):
        self.gh = gh
        self.repo = repo
        self.dry_run = dry_run

    def run(self, *args: str, write: bool = False) -> str:
        if write and self.dry_run:
            return ""
        result = subprocess.run([self.gh, *args], capture_output=True, text=True)
        if result.returncode != 0:
            raise SystemExit(f"gh {' '.join(args)} failed:\n{result.stderr.strip()}")
        if write:
            time.sleep(WRITE_PAUSE)
        return result.stdout

    def releases(self) -> dict:
        """The theme releases, by tag, with their files and download counts."""
        out = self.run("api", "--paginate", f"repos/{self.repo}/releases?per_page=100",
                       "--jq", ".[] | {id, tag_name, name, body, assets: [.assets[] | "
                               "{id, name, size, download_count, browser_download_url}]}")
        releases = [json.loads(line) for line in out.splitlines() if line.strip()]
        return {r["tag_name"]: r for r in releases if r["tag_name"].startswith(TAG_PREFIX)}

    def create(self, tag: str, title: str, notes: str, files: list, target: "str | None") -> None:
        args = ["release", "create", tag, *map(str, files), "--repo", self.repo,
                "--title", title, "--notes", notes, "--latest=false"]
        if target:
            args += ["--target", target]
        self.run(*args, write=True)

    def upload(self, tag: str, path: Path) -> None:
        self.run("release", "upload", tag, str(path), "--repo", self.repo, write=True)

    def delete_asset(self, asset_id: int) -> None:
        self.run("api", "-X", "DELETE", f"repos/{self.repo}/releases/assets/{asset_id}", write=True)

    def rename_asset(self, asset_id: int, name: str) -> None:
        self.run("api", "-X", "PATCH", f"repos/{self.repo}/releases/assets/{asset_id}", "-f", f"name={name}",
                 write=True)

    def edit(self, release_id: int, title: str, notes: str) -> None:
        self.run("api", "-X", "PATCH", f"repos/{self.repo}/releases/{release_id}",
                 "-f", f"name={title}", "-f", f"body={notes}", write=True)


def read_meta(release: dict) -> dict:
    match = META_RE.search(release.get("body") or "")
    meta = json.loads(match.group(1)) if match else {}
    meta.setdefault("carried", 0)
    # Files being replaced: asset id -> its download count when last seen.
    meta["retired"] = {int(k): v for k, v in meta.get("retired", {}).items()}
    return meta


def fold_retired(meta: dict, assets: list) -> None:
    """Moves the counts of replaced files that are gone into the carried total."""
    present = {a["id"] for a in assets}
    for asset_id in [i for i in meta["retired"] if i not in present]:
        meta["carried"] += meta["retired"].pop(asset_id)


def total_downloads(theme_id: str, meta: dict, assets: list) -> int:
    live = sum(a["download_count"] for a in assets if a["name"] == f"{theme_id}.zip")
    gone = sum(count for asset_id, count in meta["retired"].items() if asset_id not in {a["id"] for a in assets})
    return meta["carried"] + gone + live


def release_notes(theme: dict, meta: dict, site_url: str) -> str:
    by = theme["author"] or "Unknown"
    if theme["co_authors"]:
        by += " with " + ", ".join(theme["co_authors"])
    version = f" {theme['version']}" if theme["version"] else ""
    lines = [f"**{theme['name']}**{version}, a theme for Songo #5 by {by}.", ""]
    if theme["description"]:
        lines += [theme["description"], ""]
    lines += [f"Download `{theme['id']}.zip` and unzip it into Songo's `songo_themes` or "
              f"`external_themes` folder."]
    if theme["source_dir"]:
        lines += [f"`{theme['id']}-source.zip` is the theme's editable folder, for `theme_dev/themes_raw/`."]
    lines += ["", "This release always holds the theme's latest version; its files are replaced when the theme "
                  "is updated."]
    if site_url:
        lines += ["", f"All themes: {site_url}"]
    stored = dict(meta, retired={str(k): v for k, v in meta["retired"].items()})
    lines += ["", f"<!-- songo-theme: {json.dumps(stored, sort_keys=True)} -->", ""]
    return "\n".join(lines)


def title_for(theme: dict) -> str:
    return f"{theme['name']} {theme['version']}".strip()


def replace_asset(github: GitHub, release: dict, meta: dict, theme: dict, path: Path, name: str,
                  counted: bool) -> None:
    """Swaps the release's file called `name` for `path`. The new file goes up
    under a temporary name first and is renamed once the old one is gone, so
    the link is only missing for a moment. A counted file's download count is
    written to the release notes before it's deleted, so it's never lost."""
    assets = release["assets"]
    temp_name = f"{path.stem}.next{path.suffix}"
    for leftover in [a for a in assets if a["name"] == temp_name]:
        github.delete_asset(leftover["id"])  # from a run that stopped partway
    temp = path.with_name(temp_name)
    path.rename(temp)
    github.upload(release["tag_name"], temp)
    temp.rename(path)

    old = [a for a in assets if a["name"] == name]
    if counted and old:
        for asset in old:
            meta["retired"][asset["id"]] = asset["download_count"]
        github.edit(release["id"], release["name"], release_notes(theme, meta, ""))
        # The count may have moved since the listing: take the latest just before deleting.
        fresh = github.releases().get(release["tag_name"], release) if not github.dry_run else release
        for asset in fresh["assets"]:
            if asset["id"] in meta["retired"]:
                meta["retired"][asset["id"]] = max(meta["retired"][asset["id"]], asset["download_count"])
    for asset in old:
        github.delete_asset(asset["id"])
    if not github.dry_run:
        uploaded = [a for a in github.releases()[release["tag_name"]]["assets"] if a["name"] == temp_name]
        for asset in uploaded:
            github.rename_asset(asset["id"], name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Publishes theme releases and gathers download counts.")
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"GitHub repo for the releases (default: {DEFAULT_REPO})")
    parser.add_argument("--packaged", type=Path, default=site.HERE / "themes_packaged",
                        help="folder of packaged themes (default: themes_packaged next to this script)")
    parser.add_argument("--raw", type=Path, default=site.HERE / "themes_raw",
                        help="folder of theme sources (default: themes_raw next to this script)")
    parser.add_argument("--out", type=Path, default=site.HERE / "releases.json",
                        help="where to write the release details (default: releases.json next to this script)")
    parser.add_argument("--target", help="commit to tag new releases at (default: the repo's default branch)")
    parser.add_argument("--site-url", default="", help="the theme page, linked from release notes")
    parser.add_argument("--max-updates", type=int, default=40,
                        help="most themes to release or update in one run; the rest wait for the next (default: 40)")
    parser.add_argument("--gh", default="gh", help="the GitHub CLI to run (default: gh)")
    parser.add_argument("--dry-run", action="store_true", help="say what would change, change nothing")
    args = parser.parse_args()

    github = GitHub(args.gh, args.repo, args.dry_run)
    themes = site.collect_themes(args.packaged.resolve(), args.raw.resolve())
    releases = github.releases()
    print(f"{len(themes)} themes, {len(releases)} theme releases in {args.repo}")

    details = {}
    updates = 0
    deferred = []
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for theme in themes:
            theme_id = theme["id"]
            tag = TAG_PREFIX + theme_id
            release = releases.get(tag)
            meta = read_meta(release) if release else {"carried": 0, "retired": {}}
            if release:
                fold_retired(meta, release["assets"])

            # What's in the folders now, from git where possible; zipped only
            # when that can't say, or when the files have to go up.
            package = tmp / f"{theme_id}.zip"
            source = tmp / f"{theme_id}-source.zip" if theme["source_dir"] else None
            package_print = fingerprint(theme["dir"])
            source_print = fingerprint(theme["source_dir"]) if source else None
            if package_print is None:
                site.write_zip(theme["dir"], theme_id, package)
                package_print = zip_fingerprint(package)
            if source and source_print is None:
                site.write_zip(theme["source_dir"], theme_id, source)
                source_print = zip_fingerprint(source)

            names = {a["name"] for a in release["assets"]} if release else set()
            package_changed = meta.get("package") != package_print or f"{theme_id}.zip" not in names
            source_changed = source is not None and (meta.get("source") != source_print
                                                     or f"{theme_id}-source.zip" not in names)
            stale_source = source is None and f"{theme_id}-source.zip" in names
            label = title_for(theme)

            if release is None or package_changed or source_changed or stale_source:
                if updates >= args.max_updates:
                    deferred.append(theme_id)
                else:
                    updates += 1
                    if not package.exists():
                        site.write_zip(theme["dir"], theme_id, package)
                    if source and not source.exists():
                        site.write_zip(theme["source_dir"], theme_id, source)
                    if release is None:
                        meta["package"], meta["source"] = package_print, source_print
                        print(f"  {tag}: new, releasing {label}")
                        github.create(tag, label, release_notes(theme, meta, args.site_url),
                                      [package] + ([source] if source else []), args.target)
                    else:
                        what = [n for n, c in ((f"{theme_id}.zip", package_changed),
                                               (f"{theme_id}-source.zip", source_changed)) if c]
                        print(f"  {tag}: updating {', '.join(what) or 'notes'} to {label}")
                        if package_changed:
                            replace_asset(github, release, meta, theme, package, f"{theme_id}.zip", counted=True)
                        if source_changed:
                            replace_asset(github, release, meta, theme, source, f"{theme_id}-source.zip",
                                          counted=False)
                        if stale_source:
                            for asset in [a for a in release["assets"] if a["name"] == f"{theme_id}-source.zip"]:
                                github.delete_asset(asset["id"])
                        if not args.dry_run:
                            fold_retired(meta, github.releases()[tag]["assets"])
                        # Recorded last: a run that stops before here redoes the update.
                        meta["package"], meta["source"] = package_print, source_print
                        github.edit(release["id"], label, release_notes(theme, meta, args.site_url))
            else:
                print(f"  {tag}: up to date ({label})")

            details[theme_id] = {"tag": tag, "version": theme["version"]}

    if deferred:
        warn("Themes waiting", f"{len(deferred)} themes left for the next run (--max-updates {args.max_updates}): "
                               + ", ".join(deferred))
    if updates and not args.dry_run:
        releases = github.releases()

    for theme_id, detail in list(details.items()):
        release = releases.get(detail["tag"])
        if release is None:
            # Not released yet (a dry run, or waiting for the next run).
            del details[theme_id]
            continue
        meta = read_meta(release)
        assets = release["assets"]
        for asset in assets:
            if asset["name"] == f"{theme_id}.zip":
                detail["download_url"], detail["download_bytes"] = asset["browser_download_url"], asset["size"]
            elif asset["name"] == f"{theme_id}-source.zip":
                detail["source_url"], detail["source_bytes"] = asset["browser_download_url"], asset["size"]
        if "download_url" not in detail:
            del details[theme_id]
            continue
        detail.setdefault("source_url", None)
        detail.setdefault("source_bytes", None)
        detail["downloads"] = total_downloads(theme_id, meta, assets)
        print(f"  {theme_id}: {detail['downloads']} downloads")

    args.out.write_text(json.dumps({"repo": args.repo, "themes": details}, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

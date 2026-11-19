#!/usr/bin/env python3
"""Publishes each packaged theme as a GitHub release and gathers download counts.

Every theme version gets its own release, tagged <Dir>-v<version> (from the
version in its theme.json), with two files:

    <Dir>.zip          the packaged theme, ready to unzip into songo_themes/
    <Dir>-source.zip   its editable folder from themes_raw/, if it has one

A version is released once. To publish changes to a theme, raise its version;
if a theme changed but its version didn't, this leaves the release as it is
and warns. Replacing the files would reset their download counts.

A theme's download count is how many times its <Dir>.zip has been downloaded,
added up over all of its releases. Source downloads aren't counted.

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
from pathlib import Path

import build_theme_site as site

DEFAULT_REPO = "Songo-Player/Songo-5-Themes"

# Release notes end with this, holding what was released, so a later run can
# tell whether the theme has changed since.
META_RE = re.compile(r"<!-- songo-theme: (\{.*?\}) -->")
VERSION_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._-]*$")


def warn(title: str, message: str) -> None:
    # GitHub Actions shows lines like this as warnings on the run.
    print(f"::warning title={title}::{message}", file=sys.stderr)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class GitHub:
    def __init__(self, gh: str, repo: str):
        self.gh = gh
        self.repo = repo

    def run(self, *args: str) -> str:
        result = subprocess.run([self.gh, *args], capture_output=True, text=True)
        if result.returncode != 0:
            raise SystemExit(f"gh {' '.join(args)} failed:\n{result.stderr.strip()}")
        return result.stdout

    def releases(self) -> list:
        """Every release in the repo, with its files and their download counts."""
        out = self.run("api", "--paginate", f"repos/{self.repo}/releases?per_page=100",
                       "--jq", ".[] | {tag_name, body, assets: [.assets[] | "
                               "{name, size, download_count, browser_download_url}]}")
        return [json.loads(line) for line in out.splitlines() if line.strip()]

    def create(self, tag: str, title: str, notes: str, files: list, target: "str | None") -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as handle:
            handle.write(notes)
        args = ["release", "create", tag, *map(str, files), "--repo", self.repo,
                "--title", title, "--notes-file", handle.name, "--latest=false"]
        if target:
            args += ["--target", target]
        try:
            self.run(*args)
        finally:
            Path(handle.name).unlink()

    def upload(self, tag: str, files: list) -> None:
        self.run("release", "upload", tag, *map(str, files), "--repo", self.repo)


def release_notes(theme: dict, meta: dict, site_url: str) -> str:
    by = theme["author"] or "Unknown"
    if theme["co_authors"]:
        by += " with " + ", ".join(theme["co_authors"])
    lines = [f"**{theme['name']}** {theme['version']}, a theme for Songo #5 by {by}.", ""]
    if theme["description"]:
        lines += [theme["description"], ""]
    lines += [f"Download `{theme['id']}.zip` and unzip it into Songo's `songo_themes` or "
              f"`external_themes` folder."]
    if theme["source_dir"]:
        lines += [f"`{theme['id']}-source.zip` is the theme's editable folder, for `theme_dev/themes_raw/`."]
    if site_url:
        lines += ["", f"All themes: {site_url}"]
    lines += ["", f"<!-- songo-theme: {json.dumps(meta, sort_keys=True)} -->", ""]
    return "\n".join(lines)


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
    parser.add_argument("--gh", default="gh", help="the GitHub CLI to run (default: gh)")
    parser.add_argument("--dry-run", action="store_true", help="say what would be released, release nothing")
    args = parser.parse_args()

    github = GitHub(args.gh, args.repo)
    themes = site.collect_themes(args.packaged.resolve(), args.raw.resolve())
    releases = github.releases()
    by_tag = {release["tag_name"]: release for release in releases}
    print(f"{len(themes)} themes, {len(releases)} releases in {args.repo}")

    changed = False
    details = {}
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for theme in themes:
            theme_id, version = theme["id"], theme["version"]
            if not VERSION_RE.match(version):
                warn(f"{theme_id} not released",
                     f"{theme_id} has no usable version in its theme.json ({version!r}), so it can't be released")
                continue
            tag = f"{theme_id}-v{version}"
            package = tmp / f"{theme_id}.zip"
            files = [package]
            site.write_zip(theme["dir"], theme_id, package)
            meta = {"id": theme_id, "version": version, "package_sha256": sha256(package)}
            source = None
            if theme["source_dir"]:
                source = tmp / f"{theme_id}-source.zip"
                site.write_zip(theme["source_dir"], theme_id, source)
                meta["source_sha256"] = sha256(source)
                files.append(source)

            release = by_tag.get(tag)
            if release is None:
                print(f"  {tag}: new, {'would release' if args.dry_run else 'releasing'}")
                if not args.dry_run:
                    github.create(tag, f"{theme['name']} {version}", release_notes(theme, meta, args.site_url),
                                  files, args.target)
                    changed = True
            else:
                missing = [f for f in files if f.name not in {a["name"] for a in release["assets"]}]
                if missing:
                    # A release left half made, e.g. by a run that stopped partway.
                    print(f"  {tag}: adding {', '.join(f.name for f in missing)}")
                    if not args.dry_run:
                        github.upload(tag, missing)
                        changed = True
                match = META_RE.search(release.get("body") or "")
                released = json.loads(match.group(1)) if match else {}
                if released.get("package_sha256") not in (None, meta["package_sha256"]) or \
                        released.get("source_sha256") not in (None, meta.get("source_sha256")):
                    warn(f"{theme_id} changed",
                         f"{theme_id} has changed since {tag} was released. Raise the version in its "
                         f"theme.json to release the changes; {tag} keeps its files and download count.")
                else:
                    print(f"  {tag}: already released")

            details[theme_id] = {
                "tag": tag,
                "version": version,
                "download_url": f"https://github.com/{args.repo}/releases/download/{tag}/{package.name}",
                "download_bytes": package.stat().st_size,
                "source_url": f"https://github.com/{args.repo}/releases/download/{tag}/{source.name}" if source else None,
                "source_bytes": source.stat().st_size if source else None,
            }

    if changed:
        releases = github.releases()
    for theme_id, detail in details.items():
        # Sizes of the files actually released, which an unchanged rerun matches anyway.
        for release in releases:
            if release["tag_name"] != detail["tag"]:
                continue
            for asset in release["assets"]:
                if asset["name"] == f"{theme_id}.zip":
                    detail["download_url"], detail["download_bytes"] = asset["browser_download_url"], asset["size"]
                elif asset["name"] == f"{theme_id}-source.zip":
                    detail["source_url"], detail["source_bytes"] = asset["browser_download_url"], asset["size"]
        detail["downloads"] = sum(asset["download_count"] for release in releases for asset in release["assets"]
                                  if asset["name"] == f"{theme_id}.zip")
        print(f"  {theme_id}: {detail['downloads']} downloads")

    args.out.write_text(json.dumps({"repo": args.repo, "themes": details}, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

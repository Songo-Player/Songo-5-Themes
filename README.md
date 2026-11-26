# Songo-5-Themes

External themes for [Songo#5](https://github.com/Songo-Player/Songo-5), and the tools that package and publish them. Browse and download them at **https://songo-player.github.io/Songo-5-Themes/**.

This repo is the `theme_dev` folder of Songo-5, included there as a submodule. Themes are made and packaged in the Godot editor with Songo-5 open, so work on them from inside a Songo-5 checkout:

```
git clone --recurse-submodules git@github.com:Songo-Player/Songo-5.git
```

In an existing clone, run `git submodule update --init`. Before you commit, check that `theme_dev` is on `main` and not on a detached HEAD (`git switch main` in it).

## What's here

| Path | What it is |
|---|---|
| `themes_raw/<Theme>/` | each theme's editable source: scenes, scripts, assets, `theme.json`, `preview.png` |
| `themes_packaged/<Theme>/` | each theme packaged for Songo: `theme.pck`, `theme.tres`, `theme.json`, `preview.png` |
| `theme_packer.gd` | packs a theme from `themes_raw/` into `themes_packaged/` (run by the editor's Songo Themes dock) |
| `publish_releases.py` | publishes each packaged theme as a GitHub release and gathers download counts |
| `build_theme_site.py` | builds the theme page and `themes.json` |
| `.github/workflows/publish.yml` | runs both on GitHub and deploys the page |

## Adding or updating a theme

1. Open Songo-5 in the Songodot editor. In the **Songo Themes** dock, use **New Theme…** for an empty theme or **Duplicate Theme…** to start from an existing one. Either one creates `themes_raw/<Theme>/`.
2. Build the theme, and fill in its `theme.json` from the dock: name, version, author, co-authors, AI usage (0 to 5), description and tags. All of these show on the theme page.
3. Click **Pack Theme**. It writes `themes_packaged/<Theme>/` and copies it to `user://external_themes`, so Songo can load it straight away for testing.
4. Commit `themes_raw/<Theme>/` and `themes_packaged/<Theme>/`, and push (or open a PR) to `main`.

That's all: the workflow releases the theme and puts it on the page within a couple of minutes. To update a theme, change it, pack it again, and push. Raise its version in `theme.json` if you like; the release and the page show whatever version it says.

The theme's folder name is its ID: it names the release, the zip and the folder Songo installs it into. Renaming the folder makes it a new theme, with its download count starting again from 0.

**List fade and bottom margin:** in a theme's `theme.tres`, `CollectionOptions` `list_bottom_fade` and `ListSectionOuterMargin` `margin_bottom` must match. The margin leaves room below the list as tall as the fade, so the list's end, and the bar under it, sit above the fade rather than inside it. If you change one, change the other to the same value.

## Releases and download counts

Every theme has one GitHub release, `theme-<Theme>`, holding two files:

- `<Theme>.zip`: the packaged theme, ready to unzip into Songo's `songo_themes` or `external_themes` folder
- `<Theme>-source.zip`: its folder from `themes_raw/`, for editing

The download link never changes, so it's safe to link from anywhere:
`https://github.com/Songo-Player/Songo-5-Themes/releases/download/theme-<Theme>/<Theme>.zip`

On every push to `main`, and once an hour, the workflow:

1. **Checks each theme for changes** by comparing git's hash of its `themes_packaged/` and `themes_raw/` folders with the ones recorded in its release. Unchanged themes are skipped without being zipped.
2. **Creates a release** for each new theme.
3. **Replaces the files** of each changed theme's release and updates its title and notes. Old versions aren't kept.
4. **Rebuilds the page and `themes.json`** with links to the release files and each theme's download count, and deploys them to GitHub Pages.

**Download counts:**
- **What's counted:** a theme's count is how many times `<Theme>.zip` has been downloaded, across every version. Source downloads aren't counted.
- **How counts survive updates:** GitHub restarts a file's count at 0 when it's replaced. So when replacing a zip, the workflow writes that zip's count into the release notes, in a hidden `songo-theme` comment, and adds it to the total. Don't edit that comment by hand, or the counts are lost.
- **Late counts:** GitHub can count a download 10 minutes or more late, so the replaced zip stays in the release as `<Theme>.old-<id>.zip` and goes on counting. The first run after a day writes down its final count and deletes it.
- **Interrupted runs:** if a run stops partway through an update, the next run finishes it without losing or double counting anything.
- **Where counts show:** the page shows "Downloaded N times" above each theme's download buttons. The page and Songo's Theme Downloader fetch current counts from GitHub's API, keep them for 10 minutes, and fall back to the counts from the last deploy. Clicking Theme adds one on the page straight away.
- **Theme browsers:** `themes.json` on the page lists every theme with its release links and its download count as of the last deploy. Apps like theme browsers in Songo can download from those links and are counted the same way.

**Limits:**
- **Paced updates:** GitHub limits how fast releases can be created, so a run updates at most 40 themes (`--max-updates`). Any others wait for the next run and are listed as a warning on it.
- **Removed themes:** removing a theme from the repo takes it off the page, but its release stays on GitHub until you delete it.

The workflow needs **Settings > Pages > Source** set to "GitHub Actions". You can also run it by hand from the Actions tab (**Publish themes**, **Run workflow**).

## Previewing the page

```
python3 build_theme_site.py
```

This builds the page into `docs/` (ignored by git) with the theme zips alongside, so you can open `docs/index.html` and try the downloads. It lists Songo's built-in themes too, when `theme_dev` is inside Songo-5. `--help` lists the options.

To see what the workflow would release, without changing anything:

```
python3 publish_releases.py --dry-run
```

This needs the GitHub CLI (`gh`), signed in. Both scripts need only Python 3.8 or newer, with no extra packages.

## AI Usage Disclosure (2 out of 5 🤖)
Getting the github automations right was largely something claude did, the basic html page layout was also done with light claude work 

## License
Songo-5-Themes Copyright (C) 2025-2026 Riley Cleary and the themes' authors

Songo-5-Themes is licensed under the GNU General Public License version 3. See [LICENSE.txt](LICENSE.txt). Third-party assets (fonts, icons, images and other artwork) remain under their own licenses, see each theme's `CREDITS.md` where it has one. For example, the Spruce theme's spruce tree is spruceOS artwork under CC BY-NC 4.0, and isn't covered by the GPL.

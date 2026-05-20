# podmania/template

Template for creating new podmania container images. Uses [nix2container](https://github.com/nlewo/nix2container) to build distroless images designed for rootless Podman.

## Usage

Go to **Actions → Create image from template** and fill in the inputs:

| Input | Required | Description |
| --- | --- | --- |
| `name` | Yes | nixpkgs package name (e.g. `sonarr`, `qbittorrent-nox`) |
| `description` | No | Description. Auto-detected from nixpkgs if blank |
| `ports` | No | Comma-separated ports (e.g. `8080,6881`) |
| `volumes` | No | Comma-separated volumes (e.g. `/config,/data`) |
| `env` | No | Comma-separated env vars (e.g. `KEY=value,KEY2=value2`) |
| `cmd_args` | No | Comma-separated extra args (e.g. `-data=/config,-nobrowser`) |

The workflow validates the package exists in nixpkgs, renders the templates, and pushes a commit.

## What gets generated

```
podmania/<name>/
├── .github/
│   ├── FUNDING.yml
│   └── workflows/
│       ├── build-publish.yml    # Multi-arch build + GHCR push + release
│       └── update-nixpkgs.yml   # Daily flake.lock updates
├── flake.nix                    # nix2container image definition
├── compose.yml                  # Rootless Podman compose file
├── LICENSE
└── README.md
```

## How it works

- `flake.nix` uses `<%= %>` / `<% %>` jinja2 delimiters so templates don't conflict with nix expression syntax
- `render.py` sets `block_start_string="<%"` and `variable_start_string="<%="` to distinguish variables from control flow
- Build and update workflows are disabled in this template repo; they activate automatically in new repos
- Images only rebuild when the nixpkgs package version changes, not on base image updates

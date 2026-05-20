#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

from jinja2 import Environment, FileSystemLoader

TEMPLATES = [
    "flake.nix",
    "compose.yml",
    "Dockerfile",
    ".github/workflows/build-publish.yml",
]

STATIC_FILES = [
    "LICENSE",
    ".github/FUNDING.yml",
    ".github/workflows/update-nixpkgs.yml",
]


def nix_eval(attr):
    try:
        result = subprocess.run(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "eval",
                f"nixpkgs#{attr}",
                "--raw",
                "--impure",
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None


def main():
    name = os.environ.get("INPUT_NAME", "").strip()
    if not name:
        print("::error::name is required")
        sys.exit(1)

    description = os.environ.get("INPUT_DESCRIPTION", "").strip()
    ports_raw = os.environ.get("INPUT_PORTS", "").strip()
    volumes_raw = os.environ.get("INPUT_VOLUMES", "").strip()
    env_raw = os.environ.get("INPUT_ENV", "").strip()
    cmd_args_raw = os.environ.get("INPUT_CMD_ARGS", "").strip()

    if not description:
        description = nix_eval(f"{name}.meta.description") or ""

    main_program = nix_eval(f"{name}.meta.mainProgram")

    ports = [p.strip() for p in ports_raw.split(",") if p.strip()] if ports_raw else []
    volumes = [v.strip() for v in volumes_raw.split(",") if v.strip()] if volumes_raw else []
    env = [e.strip() for e in env_raw.split(",") if e.strip()] if env_raw else []
    cmd_args = [a.strip() for a in cmd_args_raw.split(",") if a.strip()] if cmd_args_raw else []

    print(f"Package: {name}")
    print(f"Description: {description}")
    print(f"Main program: {main_program}")
    print(f"Ports: {ports}")
    print(f"Volumes: {volumes}")
    print(f"Env: {env}")
    print(f"Cmd args: {cmd_args}")

    template_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.environ.get("OUTPUT_DIR", "").strip() or template_dir

    jinja_env = Environment(
        loader=FileSystemLoader(template_dir),
        keep_trailing_newline=True,
        block_start_string="<%",
        block_end_string="%>",
        variable_start_string="<%=",
        variable_end_string="%>",
    )

    context = dict(
        name=name,
        description=description,
        ports=ports,
        volumes=volumes,
        env=env,
        cmd_args=cmd_args,
        main_program=main_program,
    )

    for template_name in TEMPLATES:
        tmpl = jinja_env.get_template(template_name)
        rendered = tmpl.render(**context)
        output_path = os.path.join(output_dir, template_name)
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f:
            f.write(rendered)
        print(f"Rendered {template_name}")

    for static_file in STATIC_FILES:
        src = os.path.join(template_dir, static_file)
        dst = os.path.join(output_dir, static_file)
        if os.path.exists(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            print(f"Copied {static_file}")

    readme_path = os.path.join(output_dir, "README.md")
    with open(readme_path, "w") as f:
        f.write(f"# {name}\n\n{description}\n")
        if ports:
            f.write("\n## Ports\n\n")
            for port in ports:
                f.write(f"- `{port}`\n")
        if volumes:
            f.write("\n## Volumes\n\n")
            for volume in volumes:
                f.write(f"- `{volume}`\n")
        f.write(
            '\n<a href="https://www.buymeacoffee.com/bhoehn"'
            ' target="_blank">'
            '<img src="https://cdn.buymeacoffee.com/buttons/'
            'default-orange.png" alt="Buy Me A Coffee"'
            ' height="41" width="174"></a>\n'
        )
    print("Generated README.md")


if __name__ == "__main__":
    main()

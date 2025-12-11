# DevOps Scripts

DevOps Lazy Toolbox: Python env setup, Git auto-ops, Shell batch tasks — it handles all the chores you hate.

[![English](https://img.shields.io/badge/English-README.md-blue)](README.md) | [![中文](https://img.shields.io/badge/中文-README--zh.md-red)](README_zh.md)

## Project Initialization

Before using any tools, run the initialization script:

```bash
./init.sh
```

This script will:
- Verify project structure integrity
- Set project path configuration (`~/.devops-scripts/.devops-scripts-path`)
- Configure execution permissions for all scripts

## Tool Usage

### Unified Entry Point

Use the unified `devops` command:

```bash
./bin/devops <tool-name> [parameters...]
```

### Available Tools

#### Python Environment Manager (`python-env-manager`)

Install, activate, and manage multiple Python versions. Supports intelligent version resolution and automatic updates.

```bash
# List installed environments
./bin/devops python-env-manager --list

# Install Python (auto-resolve latest version)
./bin/devops python-env-manager --install --version 3.11

# Install specific version
./bin/devops python-env-manager --install --version 3.11.10

# Activate environment (by version)
./bin/devops python-env-manager --activate --version 3.11
# Then copy and run the displayed source command

# Activate environment (by index)
./bin/devops python-env-manager --activate --num 1

# Delete environment
./bin/devops python-env-manager --delete --num 1

# Show environment details
./bin/devops python-env-manager --details --num 1

# Validate all environments
./bin/devops python-env-manager --validate

# Clean up invalid environments
./bin/devops python-env-manager --cleanup

# List available Python versions
./bin/devops python-env-manager --list-versions

# Update version list from python.org
./bin/devops python-env-manager --update-verlist
```

#### Direct Tool Usage

You can also use individual tool scripts directly:

```bash
./bin/python-env-manager --help
```

## Project Structure

```
devops-scripts/
├── bin/                    # Tool entry scripts
│   ├── devops             # Unified tool entry
│   └── python-env-manager # Python environment manager
├── env_setup/             # Environment setup
│   └── python_env_setup/  # Python environment setup
│       ├── python_env_manager.sh    # Main script
│       ├── config_manager.sh        # Configuration manager
│       ├── python_installer.sh      # Python installer
│       ├── env_manager.sh          # Environment manager
│       └── utils.sh                # Utility functions
├── init.sh               # Project initialization script
├── README.md             # English documentation
└── README_zh.md          # Chinese documentation
```

## Configuration

- Project path config: `~/.devops-scripts/.devops-scripts-path`
- Python environment config: `~/.devops-scripts/.devops-scripts-python_env.cache`
- Default Python environment directory: `~/.devops-scripts/python_env/`

### Language Specifications

#### Log Messages
- **Must use English**: All `print_info`, `print_success`, `print_warning`, `print_error` function outputs
- **Global audience**: As a GitHub open source project, ensure worldwide developers can understand log messages

#### Code Comments
- **Can use Chinese**: Function comments, variable descriptions, code logic explanations can use Chinese
- **Improve development efficiency**: As Chinese native speakers, using Chinese comments is more convenient for development and maintenance

## Cache File Specifications

Each tool uses an independent cache file with the format `.devops-scripts-{tool-name}.cache`, which:
- Avoids configuration conflicts between different tools
- Improves configuration security and prevents accidental deletion of other tool configurations
- Supports future expansion of more tools

## Notes

- Make sure to run `./init.sh` for initialization in the project root directory
- If you move the project location, please re-run `./init.sh`
- All scripts support the `--help` parameter for detailed help information

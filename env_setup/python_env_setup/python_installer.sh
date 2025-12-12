#!/bin/bash

# Python Environment Management Tool - Python Installer
# Author: DevOps Scripts Team
# Description: Handles Python installation logic

set -euo pipefail

# Source dependency scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config_manager.sh"
source "${SCRIPT_DIR}/version_manager.sh"

# =============================================================================
# Python Installation Functions
# =============================================================================

# Check installation dependencies
check_install_dependencies() {
    local missing_commands=()
    local missing_packages=()

    # Check required commands (binary tools)
    local commands=("wget" "tar" "make" "gcc" "g++")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    # Check required system packages (development and runtime libraries)
    # Check multiple possible package name variants
    local package_checks=(
        "zlib1g-dev:zlib1g"           # Compression library
        "libssl-dev:libssl3"          # SSL library
        "libffi-dev:libffi8"          # Foreign Function Interface
        "libbz2-dev:libbz2-1.0"       # bzip2 compression
        "libreadline-dev:libreadline8" # GNU readline
        "libsqlite3-dev:libsqlite3-0"  # SQLite database
        "libexpat1-dev:libexpat1"     # XML parsing library (for pyexpat)
    )

    for pkg_check in "${package_checks[@]}"; do
        local dev_pkg="${pkg_check%%:*}"
        local runtime_pkg="${pkg_check#*:}"
        local found=false

        # Check development package (supports architecture suffixes like libssl-dev:amd64)
        local dpkg_output
        dpkg_output=$(dpkg -l 2>/dev/null)

        if echo "$dpkg_output" | grep -q "^ii  $dev_pkg"; then
            found=true
        elif echo "$dpkg_output" | grep -q "^ii  $dev_pkg:"; then
            found=true
        fi

        # If not found, try runtime package (some systems may only have runtime packages)
        if [[ "$found" == "false" ]] && echo "$dpkg_output" | grep -q "^ii  $runtime_pkg"; then
            print_warning "Found runtime package $runtime_pkg but missing dev package $dev_pkg"
            found=true
        fi

        if [[ "$found" == "false" ]]; then
            missing_packages+=("$dev_pkg")
        fi
    done

    # If any dependencies are missing, display error and exit
    if [[ ${#missing_commands[@]} -gt 0 ]] || [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_error "Missing required dependencies for Python compilation:"

        if [[ ${#missing_commands[@]} -gt 0 ]]; then
            print_error "Missing commands: ${missing_commands[*]}"
        fi

        if [[ ${#missing_packages[@]} -gt 0 ]]; then
            print_error "Missing development packages: ${missing_packages[*]}"
        fi

        print_info "Please install missing dependencies:"
        echo ""
        echo "# Update package list"
        echo "sudo apt update"
        echo ""
        echo "# Install missing commands and packages"
        local all_missing=("${missing_commands[@]}" "${missing_packages[@]}")
        echo "sudo apt install -y ${all_missing[*]}"
        echo ""
        echo "# For other Linux distributions:"
        echo "# CentOS/RHEL: sudo yum install -y make gcc gcc-c++ zlib-devel openssl-devel libffi-devel bzip2-devel readline-devel sqlite-devel wget tar"
        echo "# Fedora: sudo dnf install -y make gcc gcc-c++ zlib-devel openssl-devel libffi-devel bzip2-devel readline-devel sqlite-devel wget tar"
        echo "# Arch Linux: sudo pacman -S make gcc zlib openssl libffi bzip2 readline sqlite wget tar"

        return 1
    fi

    print_success "All installation dependencies are satisfied"
    return 0
}

# Download Python source code
download_python_source() {
    local version="$1"
    local download_dir="$2"

    # Version should already be in complete x.y.z format (handled by resolve_python_version)
    local source_url
    source_url=$(printf "$PYTHON_SOURCE_URL_TEMPLATE" "$version" "$version")

    local archive_name="Python-${version}.tgz"
    local archive_path="${download_dir}/${archive_name}"

    print_info "Downloading Python ${version} source code..."
    print_info "Download URL: $source_url"

    if ! wget -O "$archive_path" "$source_url"; then
        print_error "Failed to download Python source code"
        return 1
    fi

    print_success "Source code download completed: $archive_path"
    echo "$archive_path"
}

# Extract Python source code
extract_python_source() {
    local archive_path="$1"
    local extract_dir="$2"

    print_info "Extracting Python source code..."

    if ! tar -xzf "$archive_path" -C "$extract_dir"; then
        print_error "Failed to extract Python source code"
        return 1
    fi

    # Get the extracted directory name (using basename)
    local source_dir
    source_dir=$(basename "$archive_path" .tgz)
    source_dir="${extract_dir}/${source_dir}"

    if [[ ! -d "$source_dir" ]]; then
        print_error "Source directory not found after extraction: $source_dir"
        return 1
    fi

    print_success "Source code extraction completed: $source_dir"
    echo "$source_dir"
}

# Check build dependencies
check_build_dependencies() {
    print_info "Checking build dependencies..."

    local missing_deps=()

    # Check basic compilation tools
    if ! command -v gcc >/dev/null 2>&1; then
        missing_deps+=("gcc")
    fi
    if ! command -v make >/dev/null 2>&1; then
        missing_deps+=("make")
    fi

    # Check Python compilation dependencies
    local deps_to_check=(
        "libssl-dev:openssl/ssl.h"
        "libffi-dev:ffi.h"
        "libreadline-dev:readline/readline.h"
        "libncurses-dev:curses.h"
        "libsqlite3-dev:sqlite3.h"
        "libbz2-dev:bzlib.h"
        "liblzma-dev:lzma.h"
        "zlib1g-dev:zlib.h"
        "libgdbm-dev:gdbm.h"
        "libdb-dev:db.h"
        "tk-dev:tk.h"
        "tcl-dev:tcl.h"
        "libexpat1-dev:expat.h"
        "libmpdec-dev:mpdecimal.h"
    )

    for dep in "${deps_to_check[@]}"; do
        local pkg="${dep%%:*}"
        local header="${dep##*:}"
        if ! find /usr/include -name "$header" 2>/dev/null | head -1 >/dev/null; then
            missing_deps+=("$pkg")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Missing the following build dependencies (recommended to install):"
        printf '  %s\n' "${missing_deps[@]}"
        print_info "Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        print_info "CentOS/RHEL: sudo yum install ${missing_deps[*]/lib/-devel}"
        echo ""
    else
        print_success "All build dependencies are satisfied"
    fi
}

# Configure Python build (following distribution standards)
configure_python_build() {
    local source_dir="$1"
    local install_prefix="$2"

    print_info "Configuring Python build (distribution standard, install path: $install_prefix)..."

    cd "$source_dir"

    # Check dependencies first
    check_build_dependencies

    print_info "Configuring Python (distribution standard)..."

    # Detect system type and architecture
    local system_type=""
    local arch=""
    if [[ -f /etc/os-release ]]; then
        system_type=$(grep -E '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    fi
    arch=$(uname -m)

    # Build standard configure options (based on Ubuntu/Debian and RHEL standards)
    local configure_opts=(
        --prefix="$install_prefix"
        --enable-optimizations
        --with-ensurepip=install
        --disable-shared
        --with-system-ffi
        --with-system-expat
        --enable-loadable-sqlite-extensions
        --with-openssl=/usr
        --enable-loadable-sqlite3
        --with-readline=readline
        --with-curses
        --with-libcurses
        --enable-ipv6
        --with-zlib
        --with-bz2
        --with-lzma
    )

    # Tkinter support (if Tcl/Tk is available)
    if [[ -d /usr/include/tcl8.6 && -d /usr/include/tk8.6 ]]; then
        configure_opts+=(
            --with-tcltk-includes="-I/usr/include/tcl8.6 -I/usr/include/tk8.6"
            --with-tcltk-libs="-L/usr/lib/x86_64-linux-gnu -ltcl8.6 -ltk8.6"
        )
    fi

    # Database support
    configure_opts+=(--with-dbmliborder=bdb:gdbm)

    # Architecture-specific configuration
    case "$arch" in
        x86_64)
            configure_opts+=(--with-platlibdir="lib/x86_64-linux-gnu")
            ;;
        aarch64)
            configure_opts+=(--with-platlibdir="lib/aarch64-linux-gnu")
            ;;
    esac

    # Compilation flags
    local cflags="-O2 -I/usr/include"
    local cppflags="-I/usr/include"
    local ldflags="-L/usr/lib -Wl,--strip-all"

    # Add architecture-specific paths
    case "$system_type" in
        ubuntu|debian)
            cflags="$cflags -I/usr/include/$arch-linux-gnu"
            cppflags="$cppflags -I/usr/include/$arch-linux-gnu"
            ldflags="$ldflags -L/usr/lib/$arch-linux-gnu"
            ;;
        rhel|centos|fedora)
            cflags="$cflags -I/usr/include"
            cppflags="$cppflags -I/usr/include"
            ldflags="$ldflags -L/usr/lib64"
            ;;
    esac

    configure_opts+=(CFLAGS="$cflags" CPPFLAGS="$cppflags" LDFLAGS="$ldflags")

    print_info "Using configure options:"
    printf '  %s\n' "${configure_opts[@]}"
    echo ""

    # Execute configuration
    local configure_success=false

    if ./configure "${configure_opts[@]}" 2>&1; then
        configure_success=true
        print_success "Python configuration successful (distribution standard)"
    else
        print_warning "Standard configuration failed, trying fallback configuration..."

        # Fallback configuration: remove potentially problematic options
        local fallback_opts=(
            --prefix="$install_prefix"
            --enable-optimizations
            --with-ensurepip=install
            --disable-shared
            --with-system-ffi
            --with-system-expat
            --enable-loadable-sqlite-extensions
            --with-lzma
            CFLAGS="-O2"
            CXXFLAGS="-O2"
        )

        if ./configure "${fallback_opts[@]}" 2>&1; then
            configure_success=true
            print_success "Python configuration successful (fallback configuration)"
        else
            print_error "All configuration attempts failed"
            print_info "Please check that system dependencies are properly installed"
            return 1
        fi
    fi

    if [[ "$configure_success" == "true" ]]; then
        print_success "Python configuration completed"
        return 0
    else
        print_error "Python configuration failed"
        return 1
    fi
}

# Compiling Python
compile_python() {
    local source_dir="$1"
    local jobs="${2:-$(nproc)}"

    print_info "Compiling Python (using $jobs parallel jobs)..."

    cd "$source_dir"

    if ! make -j"$jobs"; then
        print_error "Python compilation failed"
        return 1
    fi

    print_success "Python compilation completed"
}

# Install Python
install_python() {
    local source_dir="$1"
    local install_prefix="$2"

    print_info "Installing Python to $install_prefix..."

    cd "$source_dir"

    if ! make install; then
        print_error "Python installation failed"
        return 1
    fi

    print_success "Python installation completed"
}

# Verify Python installation
verify_python_installation() {
    local install_prefix="$1"
    local python_exe="$install_prefix/bin/python3"

    print_info "Verifying Python installation..."

    if [[ ! -x "$python_exe" ]]; then
        print_error "Python executable not found at $python_exe"
        return 1
    fi

    # Test basic functionality
    print_info "Testing basic Python functionality..."

    # Test imports
    local test_imports=(
        "sys:Basic sys module"
        "os:Basic os module"
        "json:JSON support"
        "sqlite3:SQLite support"
        "ssl:SSL support"
        "lzma:LZMA/XZ support"
        "bz2:BZ2 support"
        "zlib:ZLIB support"
        "readline:Readline support"
        "curses:Curses support"
    )

    local failed_imports=()

    for test_import in "${test_imports[@]}"; do
        local module="${test_import%%:*}"
        local description="${test_import##*:}"

        if "$python_exe" -c "import $module" 2>/dev/null; then
            print_success "✓ $description"
        else
            print_warning "✗ $description (module $module not available)"
            failed_imports+=("$module")
        fi
    done

    # Test pip
    if "$python_exe" -m pip --version >/dev/null 2>&1; then
        print_success "✓ Pip support"
    else
        print_warning "✗ Pip not available"
    fi

    # Test Tkinter (if Tcl/Tk is available)
    if "$python_exe" -c "import tkinter" 2>/dev/null; then
        print_success "✓ Tkinter GUI support"
    else
        print_info "• Tkinter not available (no Tcl/Tk)"
    fi

    # Summary
    if [[ ${#failed_imports[@]} -eq 0 ]]; then
        print_success "Python installation verification completed - All core modules available!"
    else
        print_warning "Python installation completed but some optional modules are missing:"
        printf '  - %s\n' "${failed_imports[@]}"
        print_info "This is normal if corresponding system libraries were not available during compilation"
    fi

    return 0
}

# Install Python
# Manual pip installation (fallback)
install_pip_manually() {
    local python_exe="$1"

    print_info "Attempting manual pip installation..."

    # Download get-pip.py
    local get_pip_url="https://bootstrap.pypa.io/get-pip.py"
    local get_pip_file="/tmp/get-pip.py"

    if ! wget -q -O "$get_pip_file" "$get_pip_url"; then
        print_warning "Failed to download get-pip.py"
        return 1
    fi

    # Use Python to install pip
    if "$python_exe" "$get_pip_file" --user 2>&1; then
        print_success "Manual pip installation successful"
        rm -f "$get_pip_file"
        return 0
    else
        print_warning "Manual pip installation failed"
        rm -f "$get_pip_file"
        return 1
    fi
}

install_python() {
    local source_dir="$1"

    print_info "Installing Python..."

    cd "$source_dir"

    # Capture make install output for error analysis
    local output
    if ! output=$(make install 2>&1); then
        # Check if it's an ensurepip related error
        if echo "$output" | grep -q "pyexpat\|ensurepip\|ModuleNotFoundError"; then
            print_warning "ensurepip failed (possibly due to pyexpat issue), attempting manual pip installation..."

            # Get Python executable path (even if installation is incomplete)
            local python_exe="$install_path/bin/python3"
            if [[ -x "$python_exe" ]] && install_pip_manually "$python_exe"; then
                print_success "Python installation completed with manual pip installation"
                return 0
            else
                print_error "Both ensurepip and manual pip installation failed"
                echo "Installation output: $output" >&2
                return 1
            fi
        else
            print_error "Python installation failed"
            echo "Installation output: $output" >&2
            return 1
        fi
    fi

    print_success "Python installation completed"
}


# Clean up temporary files
cleanup_temp_files() {
    local temp_dir="$1"

    if [[ -d "$temp_dir" ]]; then
        print_info "Cleaning up temporary files: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Clean up failed installation directory
cleanup_failed_installation() {
    local install_path="$1"

    if [[ -d "$install_path" ]]; then
        print_warning "Cleaning up failed installation directory: $install_path"
        rm -rf "$install_path"
    fi
}

# Main function for installing Python from source
install_python_from_source() {
    local version="$1"
    local install_path="$2"
    local success_flag_file
    success_flag_file=$(mktemp)

    print_info "Starting source compilation installation of Python $version to $install_path"

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    print_info "Using temporary directory: $temp_dir"

    # Trap: Ensure cleanup of temporary files on script exit
    # Also cleanup installation directory if installation fails
    trap "cleanup_temp_files '$temp_dir'; if [[ ! -f '$success_flag_file' ]]; then cleanup_failed_installation '$install_path'; fi; rm -f '$success_flag_file'" EXIT

    # Check dependencies
    if ! check_install_dependencies; then
        print_error "Dependency check failed. Aborting installation."
        return 1
    fi

    # Check installation path
    if [[ -d "$install_path" ]] && ! is_directory_empty "$install_path"; then
        print_error "Installation path is not empty: $install_path"
        print_error "Please select an empty directory or non-existent path"
        return 1
    fi

    ensure_directory "$install_path"

    # Download source code
    local archive_path
    if ! archive_path=$(download_python_source "$version" "$temp_dir"); then
        return 1
    fi

    # Extract source code
    local source_dir
    if ! source_dir=$(extract_python_source "$archive_path" "$temp_dir"); then
        return 1
    fi

    # Configure build
    if ! configure_python_build "$source_dir" "$install_path"; then
        return 1
    fi

    # Compile
    if ! compile_python "$source_dir"; then
        return 1
    fi

    # Install
    if ! install_python "$source_dir" "$install_path"; then
        return 1
    fi

    # Verify installation
    if ! verify_python_installation "$install_path"; then
        return 1
    fi

    # Mark installation successful (create flag file)
    touch "$success_flag_file"

    print_success "Python installation successful!"
    print_info "Installation path: $install_path"

    # Show Python executable location
    local python_exe
    python_exe=$(get_python_executable "$install_path")
    print_info "Python executable: $python_exe"

    return 0
}

# Check if Python installation is needed
should_install_python() {
    local install_path="$1"

    # If path already exists in configuration, installation was already done
    if environment_path_exists "$install_path"; then
        print_warning "Path already exists in configuration, skipping installation: $install_path"
        return 1
    fi

    # Check if path is empty
    if [[ -d "$install_path" ]] && ! is_directory_empty "$install_path"; then
        print_error "Installation path is not empty and not in configuration: $install_path"
        print_error "Please select an empty directory or use a path that exists in the configuration"
        return 1
    fi

    return 0
}

# Main installation function
install_python_env() {
    local version="$1"
    local install_path="${2:-}"
    local install_method="${3:-source}"

    # Resolve version number (convert x.y to x.y.z, or validate x.y.z)
    local resolved_version
    if ! resolved_version=$(resolve_python_version "$version"); then
        return 1
    fi

    print_info "Installing Python version: $resolved_version"

    # Validate version format
    if ! validate_python_version "$resolved_version"; then
        return 1
    fi

    # Generate default installation path
    if [[ -z "$install_path" ]]; then
        install_path=$(generate_default_install_path "$resolved_version")
        print_info "Using default installation path: $install_path"
    fi

    # Check if installation is needed
    if ! should_install_python "$install_path"; then
        return 1
    fi

    # Execute installation based on method
    case "$install_method" in
        source)
            if install_python_from_source "$resolved_version" "$install_path"; then
                # Add to configuration after successful installation
                add_environment "$resolved_version" "$install_path" "$install_method"
                return 0
            else
                return 1
            fi
            ;;
        package)
            print_error "Package manager installation method not yet implemented"
            return 1
            ;;
        *)
            print_error "Unsupported installation method: $install_method"
            print_error "Supported methods: source, package"
            return 1
            ;;
    esac
}

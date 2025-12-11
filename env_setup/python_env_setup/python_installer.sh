#!/bin/bash

# Python Environment Management Tool - Python安装器
# 作者: DevOps Scripts Team
# 描述: 处理Python的安装逻辑

set -euo pipefail

# 引入依赖脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config_manager.sh"
source "${SCRIPT_DIR}/version_manager.sh"

# =============================================================================
# Python安装函数
# =============================================================================

# 检查安装依赖
check_install_dependencies() {
    local missing_commands=()
    local missing_packages=()

    # 检查必需的命令（二进制工具）
    local commands=("wget" "tar" "make" "gcc" "g++")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    # 检查必需的系统包（开发库和运行时库）
    # 同时检查多个可能的包名变体
    local package_checks=(
        "zlib1g-dev:zlib1g"           # 压缩库
        "libssl-dev:libssl3"          # SSL库
        "libffi-dev:libffi8"          # 外部函数接口
        "libbz2-dev:libbz2-1.0"       # bzip2压缩
        "libreadline-dev:libreadline8" # GNU readline
        "libsqlite3-dev:libsqlite3-0"  # SQLite数据库
    )

    for pkg_check in "${package_checks[@]}"; do
        local dev_pkg="${pkg_check%%:*}"
        local runtime_pkg="${pkg_check#*:}"
        local found=false

        # 检查开发包（支持带架构后缀的包名，如 libssl-dev:amd64）
        local dpkg_output
        dpkg_output=$(dpkg -l 2>/dev/null)

        if echo "$dpkg_output" | grep -q "^ii  $dev_pkg"; then
            found=true
        elif echo "$dpkg_output" | grep -q "^ii  $dev_pkg:"; then
            found=true
        fi

        # 如果没找到，尝试运行时包（有些系统可能只有运行时包）
        if [[ "$found" == "false" ]] && echo "$dpkg_output" | grep -q "^ii  $runtime_pkg"; then
            print_warning "Found runtime package $runtime_pkg but missing dev package $dev_pkg"
            found=true
        fi

        if [[ "$found" == "false" ]]; then
            missing_packages+=("$dev_pkg")
        fi
    done

    # 如果有任何缺失的依赖，显示错误并退出
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

# 下载Python源码
download_python_source() {
    local version="$1"
    local download_dir="$2"

    # 版本号应该已经是完整的x.y.z格式（由resolve_python_version处理）
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

# 解压Python源码
extract_python_source() {
    local archive_path="$1"
    local extract_dir="$2"

    print_info "Extracting Python source code..."

    if ! tar -xzf "$archive_path" -C "$extract_dir"; then
        print_error "Failed to extract Python source code"
        return 1
    fi

    # 获取解压后的目录名 (使用basename获取目录名)
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

# 配置Python构建
configure_python_build() {
    local source_dir="$1"
    local install_prefix="$2"

    print_info "Configuring Python build (installation path: $install_prefix)..."

    cd "$source_dir"

    # 配置构建选项
    # --prefix: Installation path
    # --enable-optimizations: 启用优化
    # --with-ensurepip=install: 安装pip
    # --disable-shared: 使用静态库，避免运行时动态链接问题
    if ! ./configure \
        --prefix="$install_prefix" \
        --enable-optimizations \
        --with-ensurepip=install \
        --disable-shared \
        --with-system-ffi \
        --with-system-expat \
        CFLAGS="-O2" \
        CXXFLAGS="-O2"; then

        print_error "Python configuration failed"
        return 1
    fi

    print_success "Python configuration completed"
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

# Installing Python
install_python() {
    local source_dir="$1"

    print_info "Installing Python..."

    cd "$source_dir"

    if ! make install; then
        print_error "Python installation failed"
        return 1
    fi

    print_success "Python installation completed"
}

# Verifying Python installation
verify_python_installation() {
    local install_prefix="$1"
    local expected_version="$2"

    print_info "Verifying Python installation..."

    # 获取Python executable路径
    local python_exe
    if ! python_exe=$(get_python_executable "$install_prefix"); then
        print_error "Cannot find installed Python executable"
        return 1
    fi

    # 检查Python版本
    local actual_version
    actual_version=$(get_python_version "$python_exe")
    if [[ -z "$actual_version" ]]; then
        print_error "Unable to get Python version information"
        return 1
    fi

    print_info "Installed Python version: $actual_version"

    # 检查主要版本是否匹配
    local expected_major_minor="${expected_version%%.*}.${expected_version#*.}"
    expected_major_minor="${expected_major_minor%%.*}"

    local actual_major_minor="${actual_version%%.*}.${actual_version#*.}"
    actual_major_minor="${actual_major_minor%%.*}"

    if [[ "$expected_major_minor" != "$actual_major_minor" ]]; then
        print_warning "Version mismatch: expected $expected_version, got $actual_version"
        # 不返回错误，因为小版本差异可能是正常的
    fi

    # 测试Python基本功能
    if ! "$python_exe" -c "import sys; print('Python测试通过')"; then
        print_error "Python basic functionality test failed"
        return 1
    fi

    # 检查pip是否可用
    if "$python_exe" -m pip --version >/dev/null 2>&1; then
        print_success "pip is installed and available"
    else
        print_warning "pip is not available"
    fi

    print_success "Python installation verification completed"
    return 0
}

# Cleaning up temporary files
cleanup_temp_files() {
    local temp_dir="$1"

    if [[ -d "$temp_dir" ]]; then
        print_info "Cleaning up temporary files: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Cleaning up failed installation directory
cleanup_failed_installation() {
    local install_path="$1"

    if [[ -d "$install_path" ]]; then
        print_warning "Cleaning up failed installation directory: $install_path"
        rm -rf "$install_path"
    fi
}

# 源码编译Installing Python的主要函数
install_python_from_source() {
    local version="$1"
    local install_path="$2"
    local success_flag_file
    success_flag_file=$(mktemp)

    print_info "Starting source compilation installation of Python $version to $install_path"

    # 创建临时目录
    local temp_dir
    temp_dir=$(mktemp -d)
    print_info "Using temporary directory: $temp_dir"

    # 陷阱：确保在脚本退出时Cleaning up temporary files
    # 如果安装失败，也清理安装目录
    trap "cleanup_temp_files '$temp_dir'; if [[ ! -f '$success_flag_file' ]]; then cleanup_failed_installation '$install_path'; fi; rm -f '$success_flag_file'" EXIT

    # 检查依赖
    if ! check_install_dependencies; then
        print_error "Dependency check failed. Aborting installation."
        return 1
    fi

    # 检查Installation path
    if [[ -d "$install_path" ]] && ! is_directory_empty "$install_path"; then
        print_error "Installation path is not empty: $install_path"
        print_error "Please select an empty directory or non-existent path"
        return 1
    fi

    ensure_directory "$install_path"

    # 下载源码
    local archive_path
    if ! archive_path=$(download_python_source "$version" "$temp_dir"); then
        return 1
    fi

    # 解压源码
    local source_dir
    if ! source_dir=$(extract_python_source "$archive_path" "$temp_dir"); then
        return 1
    fi

    # 配置构建
    if ! configure_python_build "$source_dir" "$install_path"; then
        return 1
    fi

    # 编译
    if ! compile_python "$source_dir"; then
        return 1
    fi

    # 安装
    if ! install_python "$source_dir"; then
        return 1
    fi

    # 验证安装
    if ! verify_python_installation "$install_path" "$version"; then
        return 1
    fi

    # 标记安装成功（创建标志文件）
    touch "$success_flag_file"

    print_success "Python installation successful!"
    print_info "Installation path: $install_path"

    # 显示Python executable位置
    local python_exe
    python_exe=$(get_python_executable "$install_path")
    print_info "Python executable: $python_exe"

    return 0
}

# 检查是否需要Installing Python
should_install_python() {
    local install_path="$1"

    # 如果路径已在配置中，说明已经安装过了
    if environment_path_exists "$install_path"; then
        print_warning "Path already exists in configuration, skipping installation: $install_path"
        return 1
    fi

    # 检查路径是否为空
    if [[ -d "$install_path" ]] && ! is_directory_empty "$install_path"; then
        print_error "Installation path is not empty and not in configuration: $install_path"
        print_error "Please select an empty directory or use a path that exists in the configuration"
        return 1
    fi

    return 0
}

# 主安装函数
install_python_env() {
    local version="$1"
    local install_path="${2:-}"
    local install_method="${3:-source}"

    # 解析版本号（将x.y转换为x.y.z，或验证x.y.z）
    local resolved_version
    if ! resolved_version=$(resolve_python_version "$version"); then
        return 1
    fi

    print_info "Installing Python version: $resolved_version"

    # 验证版本格式
    if ! validate_python_version "$resolved_version"; then
        return 1
    fi

    # 生成默认Installation path
    if [[ -z "$install_path" ]]; then
        install_path=$(generate_default_install_path "$resolved_version")
        print_info "Using default installation path: $install_path"
    fi

    # 检查是否需要安装
    if ! should_install_python "$install_path"; then
        return 1
    fi

    # 根据安装方法执行安装
    case "$install_method" in
        source)
            if install_python_from_source "$resolved_version" "$install_path"; then
                # 安装成功后添加到配置
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

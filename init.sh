#!/bin/bash

# DevOps Scripts - 初始化脚本
# 作者: DevOps Scripts Team
# 描述: Initializing DevOps Scripts project，设置项目路径等配置

set -euo pipefail

# =============================================================================
# 常量定义
# =============================================================================

# 项目配置文件目录
readonly CONFIG_DIR="${HOME}/.devops-scripts"
readonly PROJECT_PATH_FILE="${CONFIG_DIR}/.devops-scripts-path"

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_NC='\033[0m' # No Color

# =============================================================================
# 工具函数
# =============================================================================

# 显示带颜色的消息
print_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $*" >&2
}

print_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $*" >&2
}

print_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_NC} $*" >&2
}

print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $*" >&2
}

# Creating directory
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_info "Creating directory: $dir"
    fi
}

# 获取脚本绝对路径
get_script_dir() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$script_path"
}

# 验证项目结构
validate_project_structure() {
    local project_root="$1"

    # 检查必要的目录和文件
    local required_items=(
        "bin"
        "env_setup"
        "env_setup/python_env_setup"
        "env_setup/python_env_setup/python_env_manager.sh"
        "bin/python-env-manager"
        "bin/devops"
    )

    local missing_items=()

    for item in "${required_items[@]}"; do
        if [[ ! -e "${project_root}/${item}" ]]; then
            missing_items+=("$item")
        fi
    done

    if [[ ${#missing_items[@]} -gt 0 ]]; then
        print_error "Project structure incomplete，缺少以下文件/目录:"
        for item in "${missing_items[@]}"; do
            echo "  - $item"
        done
        return 1
    fi

    return 0
}

# =============================================================================
# 初始化函数
# =============================================================================

# 创建bin软连接
create_bin_symlink() {
    local project_root="$1"
    local bin_symlink="${CONFIG_DIR}/bin"

    # 检查软连接是否已经存在且指向正确路径
    if [[ -L "$bin_symlink" ]]; then
        local current_target
        current_target=$(readlink "$bin_symlink")
        if [[ "$current_target" == "${project_root}/bin" ]]; then
            print_info "Bin symlink already exists and points to correct path: $bin_symlink"
            return 0
        else
            print_warning "Bin symlink exists but points to different path: $current_target"
            print_info "Updating symlink to: ${project_root}/bin"
            rm "$bin_symlink"
        fi
    elif [[ -e "$bin_symlink" ]]; then
        print_error "A file or directory already exists at $bin_symlink but it's not a symlink"
        print_info "Please remove or backup this file/directory first"
        return 1
    fi

    # 创建软连接
    if ln -s "${project_root}/bin" "$bin_symlink"; then
        print_success "Created bin symlink: $bin_symlink -> ${project_root}/bin"
        return 0
    else
        print_error "Failed to create bin symlink"
        return 1
    fi
}

# 初始化项目配置
init_project_config() {
    local project_root
    project_root=$(get_script_dir)

    print_info "Initializing DevOps Scripts project..."
    print_info "Project root directory: $project_root"

    # 验证项目结构
    if ! validate_project_structure "$project_root"; then
        print_error "Project structure validation failed, please ensure all files exist"
        return 1
    fi

    # 创建配置目录
    ensure_directory "$CONFIG_DIR"

    # 检查是否已经初始化
    local need_path_update=false
    if [[ -f "$PROJECT_PATH_FILE" ]]; then
        local existing_path
        existing_path=$(cat "$PROJECT_PATH_FILE")
        if [[ "$existing_path" == "$project_root" ]]; then
            print_warning "Project already initialized, path: $existing_path"
            print_info "Checking and updating necessary configurations..."
        else
            print_warning "Found different project path configuration: $existing_path"
            print_info "Updating to new path: $project_root"
            need_path_update=true
        fi
    else
        need_path_update=true
    fi

    # 更新项目路径（如果需要）
    if [[ "$need_path_update" == "true" ]]; then
        echo "$project_root" > "$PROJECT_PATH_FILE"
        print_success "Project path saved to: $PROJECT_PATH_FILE"
    fi

    # 创建bin软连接（总是检查）
    if ! create_bin_symlink "$project_root"; then
        print_error "Failed to create bin symlink"
        return 1
    fi

    # 设置可执行权限
    print_info "Setting tool script execution permissions..."
    chmod +x "${project_root}/bin/"*
    chmod +x "${project_root}/env_setup/python_env_setup/"*.sh
    chmod +x "${project_root}/init.sh"

    print_success "DevOps Scripts project initialization completed!"
    echo ""
    echo "Now you can use the following commands:"
    echo "  ${project_root}/bin/devops --help"
    echo "  ${project_root}/bin/python-env-manager --help"
    echo ""
    echo "Or use the convenient path:"
    echo "  ${CONFIG_DIR}/bin/devops --help"
    echo "  ${CONFIG_DIR}/bin/python-env-manager --help"
    echo ""
    echo "Or add it to PATH environment variable for global use."
}

# 显示帮助信息
show_help() {
    cat << EOF
DevOps Scripts - Initialization Script

Usage:
    ./init.sh

Description:
    Initialize DevOps Scripts project, set up necessary configurations and permissions.

    This script will:
    1. Verify project structure integrity
    2. Save project root directory path to ~/.devops-scripts/.devops-scripts-path
    3. Create ~/.devops-scripts/bin symlink pointing to project bin directory
    4. Set execution permissions for all scripts

Notes:
    Please run this script in the project root directory.
    If the project is moved, please re-run this script for initialization.
    After initialization, you can conveniently access all tools via ~/.devops-scripts/bin/.

EOF
}

# 主函数
main() {
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    fi

    init_project_config
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

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

# 初始化项目配置
init_project_config() {
    local project_root
    project_root=$(get_script_dir)

    print_info "Initializing DevOps Scripts project..."
    print_info "Project root directory: $project_root"

    # 验证项目结构
    if ! validate_project_structure "$project_root"; then
        print_error "项目结构验证失败，请确保所有文件都存在"
        return 1
    fi

    # 创建配置目录
    ensure_directory "$CONFIG_DIR"

    # 检查是否已经初始化
    if [[ -f "$PROJECT_PATH_FILE" ]]; then
        local existing_path
        existing_path=$(cat "$PROJECT_PATH_FILE")
        if [[ "$existing_path" == "$project_root" ]]; then
            print_warning "项目已经初始化，路径: $existing_path"
            print_info "如果需要重新初始化，请先删除 $PROJECT_PATH_FILE 文件"
            return 0
        else
            print_warning "发现不同的项目路径配置: $existing_path"
            print_info "将更新为新路径: $project_root"
        fi
    fi

    # 写入项目路径
    echo "$project_root" > "$PROJECT_PATH_FILE"
    print_success "Project path saved到: $PROJECT_PATH_FILE"

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
    echo "或者将其添加到PATH环境变量中以全局使用。"
}

# 显示帮助信息
show_help() {
    cat << EOF
DevOps Scripts - 初始化脚本

用法:
    ./init.sh

描述:
    Initializing DevOps Scripts project，设置必要的配置和权限。

    此脚本将:
    1. 验证项目结构完整性
    2. 将Project root directory路径保存到 ~/.devops-scripts/.devops-scripts-path
    3. 设置所有脚本的执行权限

注意:
    请在Project root directory下运行此脚本。
    如果项目被移动，请重新运行此脚本进行初始化。

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
                print_error "未知参数: $1"
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

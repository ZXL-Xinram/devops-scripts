#!/bin/bash

# Python Environment Management Tool - 工具函数
# 作者: DevOps Scripts Team
# 描述: 提供Python环境管理相关的通用工具函数

set -euo pipefail

# =============================================================================
# 常量定义
# =============================================================================

# 脚本版本
[[ -z "${SCRIPT_VERSION:-}" ]] && readonly SCRIPT_VERSION="1.0.0"

# 默认配置目录
[[ -z "${DEFAULT_CONFIG_DIR:-}" ]] && readonly DEFAULT_CONFIG_DIR="${HOME}/.devops-scripts"
[[ -z "${DEFAULT_CONFIG_FILE:-}" ]] && readonly DEFAULT_CONFIG_FILE="${DEFAULT_CONFIG_DIR}/.devops-scripts-python_env.cache"

# 默认Python环境安装目录
[[ -z "${DEFAULT_PYTHON_ENV_DIR:-}" ]] && readonly DEFAULT_PYTHON_ENV_DIR="${DEFAULT_CONFIG_DIR}/python_env"

# 颜色定义
[[ -z "${COLOR_RED:-}" ]] && readonly COLOR_RED='\033[0;31m'
[[ -z "${COLOR_GREEN:-}" ]] && readonly COLOR_GREEN='\033[0;32m'
[[ -z "${COLOR_YELLOW:-}" ]] && readonly COLOR_YELLOW='\033[1;33m'
[[ -z "${COLOR_BLUE:-}" ]] && readonly COLOR_BLUE='\033[0;34m'
[[ -z "${COLOR_NC:-}" ]] && readonly COLOR_NC='\033[0m' # No Color

# Python下载URL模板
[[ -z "${PYTHON_SOURCE_URL_TEMPLATE:-}" ]] && readonly PYTHON_SOURCE_URL_TEMPLATE="https://www.python.org/ftp/python/%s/Python-%s.tgz"

# 支持的Python版本范围
[[ -z "${MIN_PYTHON_VERSION:-}" ]] && readonly MIN_PYTHON_VERSION="3.6"
[[ -z "${MAX_PYTHON_VERSION:-}" ]] && readonly MAX_PYTHON_VERSION="3.12"

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

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 获取当前时间戳
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# 获取当前日期时间
get_datetime() {
    date +"%Y-%m-%d %H:%M:%S"
}

# 验证Python版本格式
validate_python_version() {
    local version="$1"

    # 检查版本格式 (x.y 或 x.y.z)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        print_error "Invalid Python version format: $version (should be x.y or x.y.z)"
        return 1
    fi

    # 检查版本范围
    # 提取主版本号和小版本号 (x.y格式)
    local major="${version%%.*}"
    local minor="${version#*.}"
    minor="${minor%%.*}"
    local version_xy="${major}.${minor}"

    if ! version_compare "$version_xy" ">=" "$MIN_PYTHON_VERSION" || \
       ! version_compare "$version_xy" "<=" "$MAX_PYTHON_VERSION"; then
        print_error "Unsupported Python version: $version (supported range: $MIN_PYTHON_VERSION - $MAX_PYTHON_VERSION)"
        return 1
    fi

    return 0
}

# 版本比较函数
version_compare() {
    local version1="$1"
    local op="$2"
    local version2="$3"

    # 使用sort命令比较版本
    if [[ "$op" == ">=" ]]; then
        [ "$(printf '%s\n%s' "$version1" "$version2" | sort -V | head -n1)" = "$version2" ]
    elif [[ "$op" == "<=" ]]; then
        [ "$(printf '%s\n%s' "$version1" "$version2" | sort -V | head -n1)" = "$version1" ]
    elif [[ "$op" == ">" ]]; then
        [ "$version1" != "$version2" ] && [ "$(printf '%s\n%s' "$version1" "$version2" | sort -V | head -n1)" = "$version2" ]
    elif [[ "$op" == "<" ]]; then
        [ "$version1" != "$version2" ] && [ "$(printf '%s\n%s' "$version1" "$version2" | sort -V | head -n1)" = "$version1" ]
    elif [[ "$op" == "=" ]]; then
        [ "$version1" = "$version2" ]
    else
        print_error "Unsupported comparison operator: $op"
        return 1
    fi
}

# 检查目录是否为空
is_directory_empty() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]
}

# 创建目录（如果不存在）
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_info "Creating directory: $dir"
    fi
}

# 获取Python executable路径
get_python_executable() {
    local python_dir="$1"
    local python_exe="${python_dir}/bin/python3"

    if [[ -x "$python_exe" ]]; then
        echo "$python_exe"
    else
        # 尝试其他可能的路径
        python_exe="${python_dir}/python"
        if [[ -x "$python_exe" ]]; then
            echo "$python_exe"
        else
            return 1
        fi
    fi
}

# 获取Python版本信息
get_python_version() {
    local python_exe="$1"

    if [[ ! -x "$python_exe" ]]; then
        return 1
    fi

    # 获取版本信息
    local version_output
    version_output="$("$python_exe" --version 2>&1)"
    echo "$version_output" | grep -oP 'Python \K[0-9]+\.[0-9]+\.[0-9]+' || echo ""
}

# 生成默认Installation path
generate_default_install_path() {
    local version="$1"
    local timestamp
    timestamp=$(get_timestamp)
    echo "${DEFAULT_PYTHON_ENV_DIR}/python_${version}_${timestamp}"
}

# 检查是否为有效的数字
is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# 显示使用帮助
show_usage() {
    cat << EOF
Python Environment Management Tool v${SCRIPT_VERSION}

Usage:
    $0 [options] [commands]

Commands:
    --install          Install Python environment
        --version VER    Python version (required, format: x.y or x.y.z)
        --path PATH      Installation path (optional, auto-generated by default)
        --method METHOD  Installation method (optional, default: source, options: source|package)

    --list             List installed Python environments

    --activate         Activate Python environment
        --num NUM       Environment index (choose one with --version)
        --version VER   Python version (choose one with --num)

    --delete           Delete Python environment
        --num NUM       Environment index (required)

    --help             Show this help information

Examples:
    $0 --install --version 3.11
    $0 --install --version 3.9 --path /custom/path
    $0 --list
    $0 --activate --version 3.11
    $0 --activate --num 1
    $0 --delete --num 1

EOF
}

# 错误退出
error_exit() {
    local message="$1"
    local code="${2:-1}"
    print_error "$message"
    exit "$code"
}

# 确认操作
confirm_action() {
    local message="$1"
    local default="${2:-n}"

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi

    read -r -p "$prompt" response
    response="${response:-$default}"

    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]) return 1 ;;
        *) return 1 ;;
    esac
}

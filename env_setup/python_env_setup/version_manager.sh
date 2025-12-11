#!/bin/bash

# Python Environment Management Tool - 版本管理器
# 作者: DevOps Scripts Team
# 描述: 处理Python版本解析和更新逻辑

set -euo pipefail

# 引入依赖脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# =============================================================================
# 版本配置文件路径
# =============================================================================

# 避免重复定义readonly变量
if [[ -z "${VERSION_CONFIG_FILE:-}" ]]; then
    readonly VERSION_CONFIG_FILE="${SCRIPT_DIR}/version.config"
fi

# =============================================================================
# 版本管理函数
# =============================================================================

# 从version.config文件加载版本映射
load_version_config() {
    if [[ ! -f "$VERSION_CONFIG_FILE" ]]; then
        print_error "Version configuration file not found: $VERSION_CONFIG_FILE"
        return 1
    fi

    # 读取配置文件，跳过注释和空行
    declare -gA version_map
    declare -gA version_series_map
    while IFS='=' read -r key value; do
        # 跳过注释和空行
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        # 去除前后空格
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # 检查是否是版本系列配置 (key.versions)
        if [[ "$key" == *.versions ]]; then
            # 提取主版本号 (去掉.versions后缀)
            local major_minor="${key%.versions}"
            version_series_map["$major_minor"]="$value"
        else
            # 普通版本映射
            version_map["$key"]="$value"
        fi
    done < "$VERSION_CONFIG_FILE"
}

# 解析用户输入的版本号，返回完整版本号
resolve_python_version() {
    local input_version="$1"

    # 检查版本格式
    if [[ ! "$input_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        print_error "Invalid version format: $input_version"
        print_error "Expected format: x.y or x.y.z (e.g., 3.11 or 3.11.10)"
        return 1
    fi

    # 加载版本配置
    if ! load_version_config; then
        return 1
    fi
    
    # 如果是x.y格式，从配置文件查找最新的x.y.z版本
    if [[ "$input_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        if [[ -n "${version_map[$input_version]:-}" ]]; then
            local resolved_version="${version_map[$input_version]}"
            print_info "Resolved version $input_version -> $resolved_version"
            echo "$resolved_version"
            return 0
        else
            print_error "Version $input_version not found in configuration"
            print_error "Available versions:"
            list_available_versions
            print_info "You can update the version list with: --update-version"
            return 1
        fi
    fi
    
    # 如果是x.y.z格式，检查是否在配置文件中
    local major_minor="${input_version%.*}"
    if [[ -n "${version_map[$major_minor]:-}" ]]; then
        local latest_version="${version_map[$major_minor]}"
        
        # 检查用户指定的版本是否存在
        if [[ "$input_version" == "$latest_version" ]]; then
            print_info "Using version: $input_version"
            echo "$input_version"
            return 0
        else
            # 用户指定的版本不是最新版本，给出警告但继续
            print_warning "Version $input_version is not the latest for $major_minor series"
            print_warning "Latest available: $latest_version"
            print_warning "Attempting to use specified version: $input_version"
            echo "$input_version"
            return 0
        fi
    else
        print_error "Version series $major_minor not found in configuration"
        print_error "Available version series:"
        list_available_versions
        print_info "You can update the version list with: --update-version"
        return 1
    fi
}

# 列出所有可用版本
list_available_versions() {
    if ! load_version_config; then
        return 1
    fi

    print_info "Available Python versions:"
    for key in $(echo "${!version_map[@]}" | tr ' ' '\n' | sort -V); do
        echo "  $key -> ${version_map[$key]}"

        # 如果该系列有详细版本列表，显示所有版本
        if [[ -n "${version_series_map[$key]:-}" ]]; then
            # 解析patch版本列表（逗号分隔），拼接主版本号
            local patch_list="${version_series_map[$key]}"
            echo "$patch_list" | tr ',' '\n' | while read -r patch; do
                echo "    - $key.$patch"
            done
        fi
        echo ""  # 添加空行分隔不同系列
    done
}

# 从Python官网爬取最新版本信息
update_version_list() {
    print_info "Fetching latest Python versions from python.org..."
    
    # 检查curl是否可用
    if ! command_exists curl; then
        print_error "curl is required but not installed"
        print_error "Please install curl: sudo apt install curl"
        return 1
    fi
    
    # 下载Python下载页面
    local temp_file
    temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT

    # 使用合适的User-Agent和解压gzip
    if ! curl -s -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
             -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
             -H "Accept-Language: en-US,en;q=0.5" \
             --compressed \
             "https://www.python.org/downloads/source/" -o "$temp_file"; then
        print_error "Failed to fetch Python version information"
        return 1
    fi
    
    # 解析版本号（从网页内容中提取）
    # 查找类似 "Python 3.11.10 - Oct. 9, 2025" 的行
    declare -A latest_versions=()
    declare -A all_versions=()

    while IFS= read -r line; do
        # 匹配 "Python 3.X.Y - Date" 格式
        if echo "$line" | grep -q "Python [0-9]\+\.[0-9]\+\.[0-9]\+"; then
            # 提取版本号
            local full_version
            full_version=$(echo "$line" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")
            local major_minor="${full_version%.*}"
            local patch_version="${full_version##*.}"

            # 收集该系列的所有patch版本（去重）
            if [[ -z "${all_versions[$major_minor]:-}" ]]; then
                all_versions["$major_minor"]="$patch_version"
            else
                # 检查是否已存在该patch版本（精确匹配）
                if ! echo "${all_versions[$major_minor]}" | grep -q "(^|,)$patch_version(,|$)"; then
                    all_versions["$major_minor"]="${all_versions[$major_minor]},$patch_version"
                fi
            fi

            # 只保留每个系列的最新版本
            if [[ -z "${latest_versions[$major_minor]:-}" ]]; then
                latest_versions["$major_minor"]="$full_version"
            else
                # 比较版本号，保留更新的
                local current="${latest_versions[$major_minor]}"
                if version_compare "$full_version" ">" "$current"; then
                    latest_versions["$major_minor"]="$full_version"
                fi
            fi
        fi
    done < "$temp_file"

    # 对每个系列的所有patch版本进行排序和去重（最新的在前）
    for key in "${!all_versions[@]}"; do
        local sorted_patches
        sorted_patches=$(echo "${all_versions[$key]}" | tr ',' '\n' | sort -V -r | uniq | tr '\n' ',')
        # 移除末尾的逗号
        all_versions["$key"]="${sorted_patches%,}"
    done
    
    # 检查是否找到版本
    if [[ ${#latest_versions[@]} -eq 0 ]]; then
        print_error "No Python versions found on the download page"
        return 1
    fi
    
    # 备份原配置文件
    if [[ -f "$VERSION_CONFIG_FILE" ]]; then
        local backup_file="${VERSION_CONFIG_FILE}.bak"
        cp "$VERSION_CONFIG_FILE" "$backup_file"
        print_info "Backup created: $backup_file"
    fi
    
    # 生成新的配置文件
    {
        echo "# Python Version Configuration"
        echo "# Format: MAJOR.MINOR=MAJOR.MINOR.PATCH (latest version)"
        echo "# Format: MAJOR.MINOR.versions=VERSION1,VERSION2,... (all versions)"
        echo "# This file stores the latest available Python versions for each minor version"
        echo "# Last updated: $(date +%Y-%m-%d)"
        echo ""

        # 按版本号排序输出
        for key in $(echo "${!latest_versions[@]}" | tr ' ' '\n' | sort -V); do
            local major="${key%%.*}"
            echo "# Python $key series"
            echo "$key=${latest_versions[$key]}"
            if [[ -n "${all_versions[$key]:-}" ]]; then
                echo "$key.versions=${all_versions[$key]}"
            fi
            echo ""
        done
    } > "$VERSION_CONFIG_FILE"
    
    print_success "Version list updated successfully!"
    print_info "Found ${#latest_versions[@]} Python version series"
    
    # 显示更新的版本
    list_available_versions
    
    return 0
}

# 验证版本号是否可以下载
verify_version_downloadable() {
    local version="$1"
    
    # 构造下载URL
    local download_url
    download_url=$(printf "$PYTHON_SOURCE_URL_TEMPLATE" "$version" "$version")
    
    print_info "Verifying download URL: $download_url"
    
    # 使用curl检查URL是否可访问
    if ! command_exists curl; then
        print_warning "curl not available, skipping download verification"
        return 0
    fi
    
    # 使用HEAD请求检查文件是否存在
    if curl -s --head "$download_url" | grep -q "200 OK"; then
        print_success "Version $version is downloadable"
        return 0
    else
        print_error "Version $version is not available for download"
        print_error "URL: $download_url"
        return 1
    fi
}

# 获取某个版本系列的最新版本
get_latest_version_for_series() {
    local major_minor="$1"

    if ! load_version_config; then
        return 1
    fi

    if [[ -n "${version_map[$major_minor]:-}" ]]; then
        echo "${version_map[$major_minor]}"
        return 0
    else
        return 1
    fi
}

# 检查版本配置文件是否存在
check_version_config() {
    if [[ ! -f "$VERSION_CONFIG_FILE" ]]; then
        print_error "Version configuration file not found: $VERSION_CONFIG_FILE"
        print_info "Please run with --update-version to create the configuration file"
        return 1
    fi
    return 0
}


#!/bin/bash

# Python Environment Management Tool - 环境管理器
# 作者: DevOps Scripts Team
# 描述: 处理Python环境的激活、删除和查询操作

set -euo pipefail

# 引入依赖脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config_manager.sh"

# =============================================================================
# 环境管理函数
# =============================================================================

# Activating Python environment
activate_python_env() {
    local identifier="$1"  # 可以是序号或版本号
    local identifier_type="$2"  # "index" 或 "version"

    local env_info

    # 根据标识符类型获取环境信息
    case "$identifier_type" in
        index)
            if ! env_info=$(get_environment_by_index "$identifier"); then
                print_error "Environment index not found: $identifier"
                return 1
            fi
            ;;
        version)
            if ! env_info=$(find_environment_by_version_pattern "$identifier"); then
                print_error "Python version not found: $identifier"
                return 1
            fi
            ;;
        *)
            print_error "Invalid identifier type: $identifier_type"
            return 1
            ;;
    esac

    # 解析环境信息
    local version path
    version=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
    path=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['path'])")

    # 验证环境
    if ! validate_environment "$identifier" 2>/dev/null; then
        print_warning "Environment validation failed, but attempting to continue activation"
    fi

    # 获取Python executable路径
    local python_exe
    if ! python_exe=$(get_python_executable "$path"); then
        print_error "Python executable not found: $path"
        return 1
    fi

    # 创建简洁的激活/反激活脚本
    local activate_script="${path}/activate.sh"
    local deactivate_script="${path}/deactivate.sh"

    # 激活脚本 - 简洁版
    cat > "$activate_script" << EOF
#!/bin/bash
# Python $version environment activation
export PATH="$path/bin:\$PATH"
export PYTHONHOME="$path"
export LD_LIBRARY_PATH="$path/lib:\$LD_LIBRARY_PATH"
echo "Python $version environment activated"
EOF

    # 反激活脚本 - 简洁版
    cat > "$deactivate_script" << EOF
#!/bin/bash
# Python $version environment deactivation
unset PYTHONHOME
export PATH=\$(echo \$PATH | sed 's|$path/bin:||g')
unset LD_LIBRARY_PATH
echo "Python $version environment deactivated"
EOF

    chmod +x "$activate_script"
    chmod +x "$deactivate_script"

    # 输出简洁明了的命令提示
    print_success "Python environment ready!"
    echo "Version: $version"
    echo "Path: $path"
    echo ""
    echo "🔥 ACTIVATE (copy & run):"
    echo "source $activate_script"
    echo ""
    echo "🔄 DEACTIVATE (copy & run):"
    echo "source $deactivate_script"

    return 0
}

# 删除Python环境
delete_python_env() {
    local index="$1"

    # 获取环境信息
    local env_info
    if ! env_info=$(get_environment_by_index "$index"); then
        print_error "Environment index not found: $index"
        return 1
    fi

    local version path
    version=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
    path=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['path'])")

    # 显示要删除的环境信息
    echo "Python environment to be deleted:"
    echo "Index: $index"
    echo "Version: $version"
    echo "Path: $path"

    # 确认删除
    if ! confirm_action "Are you sure you want to delete this Python environment?"; then
        print_info "Operation cancelled"
        return 0
    fi

    # 检查路径是否存在
    if [[ -d "$path" ]]; then
        print_info "Deleting Python environment directory: $path"
        rm -rf "$path"
    else
        print_warning "Python environment directory does not exist: $path"
    fi

    # 从配置中移除
    remove_environment_by_index "$index"

    print_success "Python environment deletion completed: $version ($path)"
}

# 显示环境列表
show_environment_list() {
    list_environments
}

# 验证所有环境
validate_all_environments() {
    local env_count
    env_count=$(get_environment_count)

    if [[ "$env_count" -eq 0 ]]; then
        print_info "No Python environments currently installed"
        return 0
    fi

    print_info "Validating all Python environments ($env_count total)..."

    local valid_count=0
    local invalid_count=0

    for ((i=1; i<=env_count; i++)); do
        echo -n "Validating environment $i/$env_count: "

        if validate_environment "$i" >/dev/null 2>&1; then
            echo "✓"
            ((valid_count++))
        else
            echo "✗"
            ((invalid_count++))
        fi
    done

    echo ""
    print_info "Validation completed: $valid_count valid, $invalid_count invalid"

    if [[ "$invalid_count" -gt 0 ]]; then
        print_warning "Found $invalid_count invalid environments, cleanup recommended"
    fi
}

# 清理无效环境
cleanup_invalid_environments() {
    print_info "Starting cleanup of invalid environments..."

    local env_count
    env_count=$(get_environment_count)

    if [[ "$env_count" -eq 0 ]]; then
        print_info "No Python environments currently installed"
        return 0
    fi

    local invalid_indices=()

    # 收集无效环境的索引（倒序，因为删除时索引会变化）
    for ((i=env_count; i>=1; i--)); do
        if ! validate_environment "$i" >/dev/null 2>&1; then
            invalid_indices+=("$i")
        fi
    done

    if [[ ${#invalid_indices[@]} -eq 0 ]]; then
        print_info "No invalid environments found"
        return 0
    fi

    print_info "Found ${#invalid_indices[@]} invalid environments"

    for index in "${invalid_indices[@]}"; do
        echo -n "Cleaning up environment $index: "

        # Get environment information
        local env_info
        env_info=$(get_environment_by_index "$index")
        local version path
        version=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
        path=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['path'])")

        # Delete directory (if exists)
        if [[ -d "$path" ]]; then
            rm -rf "$path"
            echo "Directory deleted ✓"
        else
            echo "Directory not found ✓"
        fi

        # Remove from configuration
        remove_environment_by_index "$index"
        echo "Removed from config ✓"

        print_info "Cleaned up: $version ($path)"
    done

    print_success "Cleanup completed, cleaned ${#invalid_indices[@]} invalid environments"
}

# 显示环境详细信息
show_environment_details() {
    local index="$1"

    local env_info
    if ! env_info=$(get_environment_by_index "$index"); then
        print_error "Environment index not found: $index"
        return 1
    fi

    echo "Python environment details:"
    echo "=================="

    local version path install_method install_time status
    version=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
    path=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['path'])")
    install_method=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['install_method'])")
    install_time=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['install_time'])")
    status=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])")

    echo "Index: $index"
    echo "Version: $version"
    echo "Path: $path"
    echo "Installation method: $install_method"
    echo "Installation time: $install_time"
    echo "Status: $status"

    # 检查实际环境状态
    echo ""
    echo "Environment validation:"
    if validate_environment "$index" >/dev/null 2>&1; then
        echo "✓ Environment valid"

        # 显示Python executable
        local python_exe
        python_exe=$(get_python_executable "$path")
        echo "Python executable: $python_exe"

        # Show actual version
        local actual_version
        actual_version=$(get_python_version "$python_exe")
        echo "Actual version: $actual_version"

        # Check pip
        if "$python_exe" -m pip --version >/dev/null 2>&1; then
            echo "✓ pip available"
        else
            echo "✗ pip not available"
        fi
    else
        echo "✗ Environment invalid"
    fi
}

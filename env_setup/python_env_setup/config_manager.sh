#!/bin/bash

# Python Environment Management Tool - 配置管理器
# 作者: DevOps Scripts Team
# 描述: 管理Python环境配置文件的读写操作

set -euo pipefail

# 引入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# =============================================================================
# 配置管理函数
# =============================================================================

# 初始化配置文件
init_config_file() {
    ensure_directory "$DEFAULT_CONFIG_DIR"

    if [[ ! -f "$DEFAULT_CONFIG_FILE" ]]; then
        # 创建空的JSON配置文件
        cat > "$DEFAULT_CONFIG_FILE" << 'EOF'
{
  "version": "1.0",
  "last_updated": "",
  "environments": []
}
EOF
        print_info "Initializing configuration file: $DEFAULT_CONFIG_FILE"
    fi
}

# 获取配置数据 (返回JSON字符串)
get_config_data() {
    if [[ ! -f "$DEFAULT_CONFIG_FILE" ]]; then
        init_config_file
    fi

    cat "$DEFAULT_CONFIG_FILE"
}

# 更新配置文件
update_config_file() {
    local json_data="$1"

    # 验证JSON格式
    if ! echo "$json_data" | python3 -m json.tool >/dev/null 2>&1; then
        print_error "Invalid JSON format"
        return 1
    fi

    # 更新最后修改时间
    local current_time
    current_time=$(get_datetime)
    json_data=$(echo "$json_data" | python3 -c "
import sys, json, datetime
data = json.load(sys.stdin)
data['last_updated'] = '$current_time'
json.dump(data, sys.stdout, indent=2)
")

    echo "$json_data" > "$DEFAULT_CONFIG_FILE"
    print_info "Configuration file updated: $DEFAULT_CONFIG_FILE"
}

# 添加Python环境到配置
add_environment() {
    local version="$1"
    local path="$2"
    local install_method="${3:-source}"
    local install_time="${4:-$(get_datetime)}"

    local config_data
    config_data=$(get_config_data)

    # 检查是否已存在相同的路径
    if environment_path_exists "$path"; then
        print_warning "Path already exists in configuration: $path"
        return 1
    fi

    # 添加新环境
    local new_env
    new_env=$(cat << EOF
{
  "version": "$version",
  "path": "$path",
  "install_method": "$install_method",
  "install_time": "$install_time",
  "status": "active"
}
EOF
)

    local updated_data
    updated_data=$(echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
new_env = json.loads('''$new_env''')
data['environments'].append(new_env)
json.dump(data, sys.stdout, indent=2)
")

    update_config_file "$updated_data"
    print_success "Python environment added: $version ($path)"
}

# 删除Python环境从配置
remove_environment_by_index() {
    local index="$1"

    local config_data
    config_data=$(get_config_data)

    # 获取环境数量
    local env_count
    env_count=$(echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data['environments']))
")

    if ! is_number "$index" || [[ "$index" -lt 1 ]] || [[ "$index" -gt "$env_count" ]]; then
        print_error "Invalid environment index: $index (valid range: 1-$env_count)"
        return 1
    fi

    # 获取要删除的环境信息
    local env_info
    env_info=$(get_environment_by_index "$index")

    local updated_data
    updated_data=$(echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
index = int('$index') - 1  # 转换为0-based索引
removed_env = data['environments'].pop(index)
json.dump(data, sys.stdout, indent=2)
")

    update_config_file "$updated_data"

    local version path
    version=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
    path=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['path'])")

    print_success "Python environment removed from configuration: $version ($path)"
}

# 检查路径是否已在配置中
environment_path_exists() {
    local path="$1"

    local config_data
    config_data=$(get_config_data)

    local exists
    exists=$(echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target_path = '$path'
exists = any(env['path'] == target_path for env in data['environments'])
print('true' if exists else 'false')
")

    [[ "$exists" == "true" ]]
}

# 获取环境数量
get_environment_count() {
    local config_data
    config_data=$(get_config_data)

    echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data['environments']))
"
}

# 根据索引获取环境信息 (返回JSON字符串)
get_environment_by_index() {
    local index="$1"

    local config_data
    config_data=$(get_config_data)

    echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
index = int('$index') - 1  # 转换为0-based索引
if 0 <= index < len(data['environments']):
    print(json.dumps(data['environments'][index]))
else:
    sys.exit(1)
"
}

# 根据版本号获取环境信息 (返回JSON字符串, 多个环境时返回第一个)
get_environment_by_version() {
    local version="$1"

    local config_data
    config_data=$(get_config_data)

    echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target_version = '$version'
for env in data['environments']:
    if env['version'] == target_version:
        print(json.dumps(env))
        break
else:
    sys.exit(1)
"
}

# 根据版本模式查找环境（支持模糊匹配）
find_environment_by_version_pattern() {
    local version_pattern="$1"

    local config_data
    config_data=$(get_config_data)

    echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target_pattern = '$version_pattern'
for env in data['environments']:
    # 精确匹配
    if env['version'] == target_pattern:
        print(json.dumps(env))
        sys.exit(0)
    # 模糊匹配：如果输入的是 x.y 格式，匹配第一个 x.y.* 版本
    elif target_pattern.count('.') == 1 and env['version'].startswith(target_pattern + '.'):
        print(json.dumps(env))
        sys.exit(0)
# 如果没找到匹配的版本
sys.exit(1)
"
}

# 获取所有环境列表 (返回JSON数组字符串)
get_all_environments() {
    local config_data
    config_data=$(get_config_data)

    echo "$config_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(json.dumps(data['environments']))
"
}

# 格式化显示环境列表
list_environments() {
    local environments
    environments=$(get_all_environments)

    if [[ "$environments" == "[]" ]]; then
        print_info "No Python environments currently installed"
        return 0
    fi

    echo "Installed Python environments:"
    echo "Index  Version     Python Path"
    echo "-----  ----------  --------------------------------"

    local index=1
    echo "$environments" | python3 -c "
import sys, json
envs = json.load(sys.stdin)
for i, env in enumerate(envs, 1):
    version = env['version']
    path = env['path']
    print(f'{i:<4}  {version:<10}  {path}')
"
}

# 验证环境配置
validate_environment() {
    local index="$1"

    local env_info
    if ! env_info=$(get_environment_by_index "$index"); then
        print_error "Environment index not found: $index"
        return 1
    fi

    local path version
    path=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['path'])")
    version=$(echo "$env_info" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")

    # 检查路径是否存在
    if [[ ! -d "$path" ]]; then
        print_error "Python environment directory does not exist: $path"
        return 1
    fi

    # 检查Python executable
    local python_exe
    if ! python_exe=$(get_python_executable "$path"); then
        print_error "Python executable not found in: $path"
        return 1
    fi

    # 检查版本是否匹配
    local actual_version
    actual_version=$(get_python_version "$python_exe")
    if [[ -z "$actual_version" ]]; then
        print_error "Unable to get Python version information: $python_exe"
        return 1
    fi

    if [[ "$actual_version" != "$version" ]]; then
        print_warning "Version mismatch: configured as $version, actually $actual_version"
    fi

    print_success "Environment validation passed: $version ($path)"
    return 0
}

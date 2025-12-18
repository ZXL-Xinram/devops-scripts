#!/bin/bash

# Python Environment Management Tool - 主脚本
# 作者: DevOps Scripts Team
# 描述: Python环境管理的统一入口脚本

set -euo pipefail

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 启动路由（用于显示简洁的命令示例）
START_ROUTE=""

# 引入所有模块
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config_manager.sh"
source "${SCRIPT_DIR}/version_manager.sh"
source "${SCRIPT_DIR}/python_installer.sh"
source "${SCRIPT_DIR}/env_manager.sh"

# =============================================================================
# 参数解析和主逻辑
# =============================================================================

# 显示帮助信息
show_help() {
    local cmd_prefix="${START_ROUTE:-$0}"

    cat << EOF
Python Environment Management Tool v${SCRIPT_VERSION}

Usage:
    $cmd_prefix [options]

Commands:
    --install              Install Python environment
        --version VER       Python version (required, format: x.y or x.y.z)
        --path PATH         Installation path (optional)
        --method METHOD     Installation method (optional, default: source)

    --list                 List installed Python environments

    --activate             Activate Python environment
        --num NUM          Environment index (choose one with --version)
        --version VER      Python version (choose one with --num)

    --delete               Delete Python environment
        --num NUM          Environment index (required)

    --details              Show environment details
        --num NUM          Environment index (required)

    --validate             Validate all environments
    --cleanup              Clean up invalid environments
    --mirrors              Show Python pip mirror sources

    --list-versions        List available Python versions from config
    --update-verlist       Update Python version list from python.org

    --help                 Show this help information

Examples:
    # Install Python 3.11 (will use latest 3.11.x from config)
    $cmd_prefix --install --version 3.11

    # Install specific version
    $cmd_prefix --install --version 3.11.10

    # Install to custom path
    $cmd_prefix --install --version 3.9 --path /custom/path

    # List all environments
    $cmd_prefix --list

    # List available Python versions
    $cmd_prefix --list-versions

    # Update version list from python.org
    $cmd_prefix --update-verlist

    # Activate environment (by index)
    $cmd_prefix --activate --num 1

    # Activate environment (by version)
    $cmd_prefix --activate --version 3.11

    # Delete environment
    $cmd_prefix --delete --num 1

    # Show environment details
    $cmd_prefix --details --num 1

    # Validate all environments
    $cmd_prefix --validate

    # Clean up invalid environments
    $cmd_prefix --cleanup

    # Show pip mirror sources
    $cmd_prefix --mirrors

Configuration file: ${DEFAULT_CONFIG_FILE}
Default environment directory: ${DEFAULT_PYTHON_ENV_DIR}

EOF
}

# 解析命令行参数
parse_arguments() {
    # 如果没有参数，显示帮助
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    # 参数变量
    local command=""
    local version=""
    local path=""
    local method="source"
    local num=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --start-route)
                if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
                    print_error "--start-route parameter requires a value"
                    exit 1
                fi
                START_ROUTE="$2"
                shift 2
                ;;
            --install)
                command="install"
                shift
                ;;
            --list)
                command="list"
                shift
                ;;
            --activate)
                command="activate"
                shift
                ;;
            --delete)
                command="delete"
                shift
                ;;
            --details)
                command="details"
                shift
                ;;
            --validate)
                command="validate"
                shift
                ;;
            --cleanup)
                command="cleanup"
                shift
                ;;
            --mirrors)
                command="mirrors"
                shift
                ;;
            --list-versions)
                command="list-versions"
                shift
                ;;
            --update-verlist)
                command="update-verlist"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --version)
                if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
                    print_error "Parameter.*requires a value"
                    exit 1
                fi
                version="$2"
                shift 2
                ;;
            --path)
                if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
                    print_error "Parameter.*requires a value"
                    exit 1
                fi
                path="$2"
                shift 2
                ;;
            --method)
                if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
                    print_error "Parameter.*requires a value"
                    exit 1
                fi
                method="$2"
                shift 2
                ;;
            --num)
                if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
                    print_error "Parameter.*requires a value"
                    exit 1
                fi
                num="$2"
                shift 2
                ;;
            *)
                print_error "Unknown parameter: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done

    # 执行命令
    execute_command "$command" "$version" "$path" "$method" "$num"
}

# 执行命令
execute_command() {
    local command="$1"
    local version="$2"
    local path="$3"
    local method="$4"
    local num="$5"

    case "$command" in
        install)
            if [[ -z "$version" ]]; then
                print_error "Install command requires --version parameter"
                exit 1
            fi
            install_python_env "$version" "$path" "$method"
            ;;
        list)
            show_environment_list
            ;;
        activate)
            if [[ -n "$num" ]] && [[ -n "$version" ]]; then
                print_error "Activation command cannot specify both --num and --version"
                exit 1
            elif [[ -n "$num" ]]; then
                activate_python_env "$num" "index"
            elif [[ -n "$version" ]]; then
                activate_python_env "$version" "version"
            else
                print_error "Activation command requires --num or --version parameter"
                exit 1
            fi
            ;;
        delete)
            if [[ -z "$num" ]]; then
                print_error "Delete command requires --num parameter"
                exit 1
            fi
            delete_python_env "$num"
            ;;
        details)
            if [[ -z "$num" ]]; then
                print_error "Details command requires --num parameter"
                exit 1
            fi
            show_environment_details "$num"
            ;;
        validate)
            validate_all_environments
            ;;
        cleanup)
            cleanup_invalid_environments
            ;;
        mirrors)
            show_pip_mirrors
            ;;
        list-versions)
            list_available_versions
            ;;
        update-verlist)
            update_version_list
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# 主函数
main() {
    print_info "Python Environment Management Tool v${SCRIPT_VERSION}"

    # 初始化配置
    init_config_file

    # 解析并执行命令
    parse_arguments "$@"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

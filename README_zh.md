# DevOps Scripts

DevOps 懒人工具箱：Python环境搭建、Git自动操作、Shell批量任务 — 帮你处理所有讨厌的杂活。

[![English](https://img.shields.io/badge/English-README.md-blue)](README.md) | [![中文](https://img.shields.io/badge/中文-README--zh.md-red)](README_zh.md)

## 项目初始化

在使用任何工具之前，请先运行初始化脚本：

```bash
./init.sh
```

此脚本将：
- 验证项目结构完整性
- 设置项目路径配置 (`~/.devops-scripts/.devops-scripts-path`)
- 配置所有脚本的执行权限

## 工具使用

### 统一入口

使用统一的 `devops` 命令：

```bash
./bin/devops <工具名> [参数...]
```

### 可用工具

#### Python环境管理 (`python-env-manager`)

用于安装、激活、管理多个Python版本。支持智能版本解析和自动版本更新。

```bash
# 列出已安装的环境
./bin/devops python-env-manager --list

# 安装Python（自动解析最新版本）
./bin/devops python-env-manager --install --version 3.11

# 安装指定版本
./bin/devops python-env-manager --install --version 3.11.10

# 激活环境（通过版本号）
./bin/devops python-env-manager --activate --version 3.11
# 然后复制并执行显示的source命令

# 激活环境（通过序号）
./bin/devops python-env-manager --activate --num 1

# 删除环境
./bin/devops python-env-manager --delete --num 1

# 显示环境详细信息
./bin/devops python-env-manager --details --num 1

# 验证所有环境
./bin/devops python-env-manager --validate

# 清理无效环境
./bin/devops python-env-manager --cleanup

# 列出可用Python版本
./bin/devops python-env-manager --list-versions

# 从python.org更新版本列表
./bin/devops python-env-manager --update-verlist
```

#### 直接使用工具脚本

也可以直接使用各个工具脚本：

```bash
./bin/python-env-manager --help
```

## 项目结构

```
devops-scripts/
├── bin/                    # 工具入口脚本目录
│   ├── devops             # 统一工具入口
│   └── python-env-manager # Python环境管理工具
├── env_setup/             # 环境设置相关
│   └── python_env_setup/  # Python环境设置
│       ├── python_env_manager.sh    # 主脚本
│       ├── config_manager.sh        # 配置管理
│       ├── python_installer.sh      # Python安装器
│       ├── env_manager.sh          # 环境管理器
│       └── utils.sh                # 工具函数
├── init.sh               # 项目初始化脚本
├── README.md             # 英文文档
└── README_zh.md          # 中文文档
```

## 配置说明

- 项目路径配置: `~/.devops-scripts/.devops-scripts-path`
- Python环境配置: `~/.devops-scripts/.devops-scripts-python_env.cache`
- 默认Python环境目录: `~/.devops-scripts/python_env/`

### 语言规范

### 日志信息
- **必须使用英文**: 所有 `print_info`, `print_success`, `print_warning`, `print_error` 等函数的输出信息
- **面向全球用户**: 作为GitHub开源项目，确保全世界开发者都能理解日志信息

### 代码注释
- **可以使用中文**: 函数注释、变量说明、代码逻辑解释可以使用中文
- **提高开发效率**: 作为中文母语者，使用中文注释更方便开发和维护

## 缓存文件规范

每个工具使用独立的缓存文件，格式为 `.devops-scripts-{工具名称}.cache`，这样可以：
- 避免不同工具之间的配置冲突
- 提高配置安全性，防止误删除其他工具配置
- 支持未来扩展更多工具

## 注意事项

- 请确保在项目根目录运行 `./init.sh` 进行初始化
- 如果移动了项目位置，请重新运行 `./init.sh`
- 所有脚本都支持 `--help` 参数查看详细帮助信息

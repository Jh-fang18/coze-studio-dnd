#!/bin/bash

# 高级同步上游仓库脚本
# 支持 merge 和 rebase 两种合并方式

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
UPSTREAM_REPO="https://github.com/coze-dev/coze-studio.git"
UPSTREAM_REMOTE="upstream"
DEFAULT_BRANCH="main"
MERGE_STRATEGY="merge"  # merge 或 rebase

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_cyan() { echo -e "${CYAN}$1${NC}"; }

# 显示使用说明
show_usage() {
    cat << EOF
${CYAN}同步上游仓库脚本${NC}

用法:
    $0 [选项] [上游分支名]

选项:
    -b, --branch BRANCH     指定上游分支名 (默认: main)
    -s, --strategy STRATEGY 合并策略: merge 或 rebase (默认: merge)
    -f, --force             强制同步，即使工作区有未提交的更改
    -h, --help              显示此帮助信息

示例:
    $0                                    # 使用默认设置同步 main 分支
    $0 -b main -s merge                  # 使用 merge 策略同步 main 分支
    $0 -b develop -s rebase              # 使用 rebase 策略同步 develop 分支
    $0 --force                            # 强制同步（会暂存当前更改）

合并策略说明:
    merge  - 创建一个合并提交，保留完整的提交历史
    rebase - 将本地提交重新应用到上游代码之上，保持线性历史

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch)
                DEFAULT_BRANCH="$2"
                shift 2
                ;;
            -s|--strategy)
                if [[ "$2" != "merge" && "$2" != "rebase" ]]; then
                    print_error "合并策略必须是 'merge' 或 'rebase'"
                    exit 1
                fi
                MERGE_STRATEGY="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_SYNC=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [[ -z "$DEFAULT_BRANCH_SET" ]]; then
                    DEFAULT_BRANCH="$1"
                    DEFAULT_BRANCH_SET=true
                else
                    print_error "未知参数: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# 检查 Git 仓库
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "当前目录不是 Git 仓库！"
        exit 1
    fi
}

# 检查工作区
check_working_directory() {
    if ! git diff-index --quiet HEAD --; then
        if [[ "$FORCE_SYNC" == "true" ]]; then
            print_warning "工作区有未提交的更改，将自动暂存..."
            git stash push -m "Auto-stashed by sync-upstream script at $(date +%Y-%m-%d\ %H:%M:%S)"
            STASHED=true
            print_success "已暂存当前更改"
        else
            print_error "工作区有未提交的更改！"
            echo ""
            echo "请先提交或暂存你的更改，或者使用 --force 参数自动暂存"
            exit 1
        fi
    fi
}

# 设置上游仓库
setup_upstream() {
    if git remote | grep -q "^${UPSTREAM_REMOTE}$"; then
        print_info "上游远程仓库已存在: ${UPSTREAM_REMOTE}"
        CURRENT_URL=$(git remote get-url ${UPSTREAM_REMOTE})
        if [ "$CURRENT_URL" != "$UPSTREAM_REPO" ]; then
            print_warning "更新上游远程仓库 URL..."
            git remote set-url ${UPSTREAM_REMOTE} ${UPSTREAM_REPO}
        fi
    else
        print_info "添加上游远程仓库..."
        git remote add ${UPSTREAM_REMOTE} ${UPSTREAM_REPO}
        print_success "已添加上游远程仓库"
    fi
}

# 获取上游代码
fetch_upstream() {
    print_info "正在从上游获取最新代码..."
    git fetch ${UPSTREAM_REMOTE} ${DEFAULT_BRANCH}
    print_success "已获取上游最新代码"
}

# 显示分支信息
show_branch_info() {
    local upstream_branch="${UPSTREAM_REMOTE}/${DEFAULT_BRANCH}"
    local current_branch=$(git branch --show-current)
    
    echo ""
    print_cyan "=== 分支信息 ==="
    echo "  当前分支: ${current_branch}"
    echo "  上游分支: ${upstream_branch}"
    echo "  合并策略: ${MERGE_STRATEGY}"
    
    if git show-ref --verify --quiet refs/remotes/${upstream_branch}; then
        local ahead=$(git rev-list --count ${upstream_branch}..HEAD 2>/dev/null || echo "0")
        local behind=$(git rev-list --count HEAD..${upstream_branch} 2>/dev/null || echo "0")
        echo "  本地领先: ${ahead} 个提交"
        echo "  上游领先: ${behind} 个提交"
    fi
    echo ""
}

# 执行合并
do_merge() {
    local upstream_branch="${UPSTREAM_REMOTE}/${DEFAULT_BRANCH}"
    
    if ! git show-ref --verify --quiet refs/remotes/${upstream_branch}; then
        print_error "上游分支 ${upstream_branch} 不存在！"
        echo ""
        print_info "可用的上游分支："
        git branch -r | grep "${UPSTREAM_REMOTE}/" | sed 's/^[ ]*/  /'
        exit 1
    fi
    
    print_info "正在使用 ${MERGE_STRATEGY} 策略合并..."
    
    if [[ "$MERGE_STRATEGY" == "rebase" ]]; then
        if git rebase ${upstream_branch}; then
            print_success "Rebase 成功！"
        else
            print_error "Rebase 失败，存在冲突！"
            echo ""
            echo "请手动解决冲突："
            echo "  1. 查看冲突文件: git status"
            echo "  2. 编辑冲突文件，解决冲突"
            echo "  3. 标记冲突已解决: git add <file>"
            echo "  4. 继续 rebase: git rebase --continue"
            echo "  5. 或取消 rebase: git rebase --abort"
            exit 1
        fi
    else
        if git merge ${upstream_branch} --no-edit; then
            print_success "Merge 成功！"
        else
            print_error "Merge 失败，存在冲突！"
            echo ""
            echo "请手动解决冲突："
            echo "  1. 查看冲突文件: git status"
            echo "  2. 编辑冲突文件，解决冲突"
            echo "  3. 标记冲突已解决: git add <file>"
            echo "  4. 完成合并: git commit"
            echo "  5. 或取消合并: git merge --abort"
            exit 1
        fi
    fi
}

# 恢复暂存的更改
restore_stash() {
    if [[ "$STASHED" == "true" ]]; then
        print_info "正在恢复暂存的更改..."
        if git stash pop; then
            print_success "已恢复暂存的更改"
        else
            print_warning "恢复暂存的更改时出现冲突，请手动解决"
        fi
    fi
}

# 显示后续操作提示
show_next_steps() {
    echo ""
    print_cyan "=== 后续操作 ==="
    echo "  查看提交历史: git log --oneline --graph -10"
    echo "  推送到远程: git push"
    if [[ "$MERGE_STRATEGY" == "rebase" ]]; then
        echo "  强制推送 (如果已推送过): git push --force-with-lease"
    fi
    echo "  查看差异: git diff ${UPSTREAM_REMOTE}/${DEFAULT_BRANCH}..HEAD"
    echo ""
}

# 主函数
main() {
    parse_args "$@"
    
    print_cyan "========================================="
    print_cyan "  同步上游仓库脚本"
    print_cyan "========================================="
    echo ""
    
    check_git_repo
    check_working_directory
    setup_upstream
    fetch_upstream
    show_branch_info
    do_merge
    restore_stash
    show_next_steps
    
    print_success "同步完成！"
}

# 运行主函数
main "$@"


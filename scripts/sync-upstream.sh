#!/bin/bash

# 同步上游仓库脚本
# 用于从上游（upstream）项目获取最新代码并合并到本地

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 上游仓库地址（扣子官方仓库）
UPSTREAM_REPO="https://github.com/coze-dev/coze-studio.git"
UPSTREAM_REMOTE="upstream"
CURRENT_BRANCH=$(git branch --show-current)

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在 git 仓库中
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "当前目录不是 Git 仓库！"
        exit 1
    fi
}

# 检查工作区是否干净
check_working_directory() {
    if ! git diff-index --quiet HEAD --; then
        print_warning "工作区有未提交的更改！"
        echo "请先提交或暂存你的更改，然后再运行此脚本。"
        echo ""
        echo "你可以："
        echo "  1. 提交更改: git add . && git commit -m 'your message'"
        echo "  2. 暂存更改: git stash"
        echo "  3. 放弃更改: git reset --hard HEAD"
        exit 1
    fi
}

# 检查并添加上游远程仓库
setup_upstream() {
    if git remote | grep -q "^${UPSTREAM_REMOTE}$"; then
        print_info "上游远程仓库已存在: ${UPSTREAM_REMOTE}"
        # 检查 URL 是否正确
        CURRENT_URL=$(git remote get-url ${UPSTREAM_REMOTE})
        if [ "$CURRENT_URL" != "$UPSTREAM_REPO" ]; then
            print_warning "上游远程仓库 URL 不匹配，更新中..."
            git remote set-url ${UPSTREAM_REMOTE} ${UPSTREAM_REPO}
            print_success "已更新上游远程仓库 URL"
        fi
    else
        print_info "添加上游远程仓库: ${UPSTREAM_REMOTE}"
        git remote add ${UPSTREAM_REMOTE} ${UPSTREAM_REPO}
        print_success "已添加上游远程仓库"
    fi
}

# 获取上游最新代码
fetch_upstream() {
    print_info "正在从上游获取最新代码..."
    git fetch ${UPSTREAM_REMOTE}
    print_success "已获取上游最新代码"
}

# 显示可用的上游分支
show_upstream_branches() {
    print_info "可用的上游分支："
    git branch -r | grep "${UPSTREAM_REMOTE}/" | sed 's/^[ ]*/  /' | head -10
}

# 合并上游代码
merge_upstream() {
    local upstream_branch=${1:-"main"}
    local full_upstream_branch="${UPSTREAM_REMOTE}/${upstream_branch}"
    
    # 检查上游分支是否存在
    if ! git show-ref --verify --quiet refs/remotes/${full_upstream_branch}; then
        print_error "上游分支 ${full_upstream_branch} 不存在！"
        show_upstream_branches
        exit 1
    fi
    
    print_info "当前分支: ${CURRENT_BRANCH}"
    print_info "正在合并上游分支: ${full_upstream_branch}"
    
    # 尝试合并
    if git merge ${full_upstream_branch} --no-edit; then
        print_success "合并成功！"
        print_info "你可以运行 'git log' 查看合并提交"
    else
        print_error "合并失败，存在冲突！"
        echo ""
        echo "请手动解决冲突："
        echo "  1. 查看冲突文件: git status"
        echo "  2. 编辑冲突文件，解决冲突"
        echo "  3. 标记冲突已解决: git add <file>"
        echo "  4. 完成合并: git commit"
        echo ""
        echo "或者取消合并: git merge --abort"
        exit 1
    fi
}

# 显示合并统计
show_merge_stats() {
    print_info "合并统计："
    echo "  新增提交数: $(git rev-list --count HEAD ^${UPSTREAM_REMOTE}/main 2>/dev/null || echo 'N/A')"
    echo "  当前分支领先: $(git rev-list --count ${UPSTREAM_REMOTE}/main..HEAD 2>/dev/null || echo 'N/A')"
    echo "  上游分支领先: $(git rev-list --count HEAD..${UPSTREAM_REMOTE}/main 2>/dev/null || echo 'N/A')"
}

# 主函数
main() {
    print_info "开始同步上游代码..."
    echo ""
    
    # 解析参数
    UPSTREAM_BRANCH="main"
    if [ "$1" != "" ]; then
        UPSTREAM_BRANCH=$1
    fi
    
    # 执行步骤
    check_git_repo
    check_working_directory
    setup_upstream
    fetch_upstream
    merge_upstream ${UPSTREAM_BRANCH}
    
    echo ""
    print_success "同步完成！"
    show_merge_stats
    echo ""
    print_info "提示："
    echo "  - 查看合并日志: git log --oneline --graph"
    echo "  - 推送到远程: git push"
    echo "  - 查看差异: git diff ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}..HEAD"
}

# 运行主函数
main "$@"


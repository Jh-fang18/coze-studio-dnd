# 同步上游仓库脚本使用说明

这些脚本用于从上游（upstream）仓库同步最新代码并合并到本地分支。

## 脚本说明

### 1. `sync-upstream.sh` - 基础版本

简单易用的同步脚本，使用 merge 策略合并代码。

**使用方法：**
```bash
# 同步 main 分支（默认）
./scripts/sync-upstream.sh

# 同步指定分支
./scripts/sync-upstream.sh develop
```

**功能：**
- ✅ 自动检查并添加上游远程仓库
- ✅ 检查工作区是否干净
- ✅ 获取上游最新代码
- ✅ 使用 merge 策略合并
- ✅ 显示合并统计信息

### 2. `sync-upstream-advanced.sh` - 高级版本

功能更强大的同步脚本，支持多种合并策略和选项。

**使用方法：**
```bash
# 显示帮助信息
./scripts/sync-upstream-advanced.sh --help

# 使用默认设置（merge 策略，main 分支）
./scripts/sync-upstream-advanced.sh

# 使用 rebase 策略
./scripts/sync-upstream-advanced.sh -s rebase

# 同步指定分支
./scripts/sync-upstream-advanced.sh -b develop

# 强制同步（自动暂存未提交的更改）
./scripts/sync-upstream-advanced.sh --force

# 组合使用
./scripts/sync-upstream-advanced.sh -b develop -s rebase --force
```

**选项说明：**
- `-b, --branch BRANCH`: 指定上游分支名（默认: main）
- `-s, --strategy STRATEGY`: 合并策略，可选 `merge` 或 `rebase`（默认: merge）
- `-f, --force`: 强制同步，即使工作区有未提交的更改（会自动暂存）
- `-h, --help`: 显示帮助信息

**合并策略对比：**

| 策略 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| merge | 保留完整历史，安全 | 产生合并提交，历史较复杂 | 团队协作，需要保留完整历史 |
| rebase | 线性历史，更清晰 | 需要解决冲突，可能改写历史 | 个人开发，希望保持干净的历史 |

## 使用流程

### 第一次使用

1. **确保已 fork 并克隆了仓库**
   ```bash
   git clone https://github.com/YOUR_USERNAME/coze-studio.git
   cd coze-studio
   ```

2. **运行同步脚本**
   ```bash
   ./scripts/sync-upstream.sh
   ```

   脚本会自动：
   - 添加上游远程仓库（如果不存在）
   - 获取最新代码
   - 合并到当前分支

### 日常使用

每次需要同步上游代码时：

```bash
# 方式 1: 使用基础脚本（推荐新手）
./scripts/sync-upstream.sh

# 方式 2: 使用高级脚本（推荐有经验的开发者）
./scripts/sync-upstream-advanced.sh -s rebase
```

### 处理冲突

如果合并时出现冲突：

1. **查看冲突文件**
   ```bash
   git status
   ```

2. **编辑冲突文件**
   打开冲突文件，查找 `<<<<<<<`, `=======`, `>>>>>>>` 标记，手动解决冲突

3. **标记冲突已解决**
   ```bash
   git add <冲突文件>
   ```

4. **完成合并**
   - 如果是 merge: `git commit`
   - 如果是 rebase: `git rebase --continue`

5. **或取消合并**
   - 如果是 merge: `git merge --abort`
   - 如果是 rebase: `git rebase --abort`

## 常见问题

### Q: 工作区有未提交的更改怎么办？

**方式 1: 提交更改**
```bash
git add .
git commit -m "your message"
./scripts/sync-upstream.sh
```

**方式 2: 暂存更改**
```bash
git stash
./scripts/sync-upstream.sh
git stash pop  # 恢复暂存的更改
```

**方式 3: 使用强制模式（高级脚本）**
```bash
./scripts/sync-upstream-advanced.sh --force
```

### Q: 如何查看同步后的差异？

```bash
# 查看与上游的差异
git diff upstream/main..HEAD

# 查看提交历史
git log --oneline --graph -20
```

### Q: 如何推送到远程仓库？

```bash
# 普通推送（merge 策略）
git push

# 强制推送（rebase 策略，如果之前已推送过）
git push --force-with-lease
```

### Q: 如何查看上游分支列表？

```bash
git fetch upstream
git branch -r | grep upstream/
```

## 最佳实践

1. **定期同步**: 建议每天或每次开发前同步一次上游代码
2. **保持工作区干净**: 同步前提交或暂存所有更改
3. **使用 rebase**: 如果希望保持干净的提交历史，使用 rebase 策略
4. **解决冲突**: 及时解决冲突，避免积累过多冲突
5. **测试验证**: 同步后运行测试，确保代码正常工作

## 故障排查

### 问题: 找不到上游分支

**解决**: 检查分支名是否正确
```bash
git fetch upstream
git branch -r | grep upstream/
```

### 问题: 权限错误

**解决**: 确保你有推送权限，或检查远程仓库配置
```bash
git remote -v
```

### 问题: 合并后代码有问题

**解决**: 可以回退到合并前的状态
```bash
git reflog  # 查看操作历史
git reset --hard HEAD@{n}  # 回退到指定位置
```

## 相关命令

```bash
# 查看远程仓库
git remote -v

# 查看当前分支
git branch --show-current

# 查看提交历史
git log --oneline --graph

# 查看与上游的差异
git diff upstream/main..HEAD

# 查看本地和上游的提交统计
git rev-list --left-right --count HEAD...upstream/main
```


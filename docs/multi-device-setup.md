# 多设备、多软件同步安装（仓库 owner 专用）

> 本方案适用于把本仓库作为「唯一真源」，在你自己的多台设备、多个 AI 软件（Claude Code / Codex / Cursor / TRAE 等）之间保持 skill 集合一致。

## 核心思路

1. **GitHub 仓库 = 唯一真源**：所有 skill 源码都集中在本仓库的 `skills/` 目录。
2. **本地 clone 一份**：每台设备 clone 一次仓库到固定路径。
3. **软链接（Junction）挂载**：在每个软件的 skill 目录里，用 Junction 指向仓库里对应的 skill 文件夹。

这样改一处、全软件即时生效；`git pull` 一次、全设备同步。Junction 在 Windows 上无需管理员权限（Symbolic Link 才需要）。

## 新设备首次接入

在 PowerShell 里执行：

```powershell
cd $env:USERPROFILE
git clone https://github.com/<你的用户名>/amazon-skills.git amazon-skills
powershell -ExecutionPolicy Bypass -File .\amazon-skills\setup-skills.ps1 -IncludeTrae
```

`setup-skills.ps1` 会自动：

- 遍历 `skills\` 下的所有 skill；
- 给 Codex / Claude / Cursor 三个软件的 skill 目录建 Junction；
- 加 `-IncludeTrae` 后，额外扫描 TRAE 的 `work-mode-projects\*\.trae\skills`，给每个项目都链接。

脚本是幂等的：已存在的链接会跳过（输出 `[kept]`），只给新增 skill 建链接（输出 `[link]`），可放心重复运行。

## 日常操作（三步）

新增 / 修改 / 删除 skill 后：

```powershell
# 1) 在 skills\ 目录里编辑（新增/修改/删除）

# 2) 提交并推送到远程
cd $env:USERPROFILE\amazon-skills
git add -A; git commit -m "update skills"; git push

# 3) 其他设备同步并重新挂载
git pull
powershell -ExecutionPolicy Bypass -File .\setup-skills.ps1 -IncludeTrae
```

## 注意事项

- **TRAE 是「项目级」技能**：每个项目各自的 `.trae\skills` 都要链接，所以新电脑 / 新项目记得带上 `-IncludeTrae` 重跑一次。
- **PowerShell 5 执行 `.ps1`**：默认执行策略会拦截，需加 `-ExecutionPolicy Bypass`；或一次性执行 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`，之后就能直接 `.\setup-skills.ps1`。
- **删除 skill 的顺序**：先在各软件目录删除对应 Junction，再从仓库删除源目录，最后提交推送，避免残留悬空链接。
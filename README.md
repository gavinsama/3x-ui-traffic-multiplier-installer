# 3x-ui v3.11.0 流量倍率版：FinalShell 安装

本仓库只用于公开分发安装脚本、Linux amd64 程序包和对应的完整源码包。开发仓库保持私有。安装脚本提供两个菜单选项：

1. 已安装官方 3x-ui v3.11.0：备份现有 SQLite 数据与原程序，再替换面板程序。
2. 全新 VPS：先安装固定版本的官方 v3.11.0，再备份和替换面板程序。

在 FinalShell 连接 VPS 后，以 root 身份在 SSH 终端执行：

```bash
install -d -m 700 /root/x-ui-multiplier-installer &&
curl -fsSL --retry 3 --connect-timeout 15 https://raw.githubusercontent.com/gavinsama/3x-ui-traffic-multiplier-installer/main/install-multiplier.sh -o /root/x-ui-multiplier-installer/install-multiplier.sh &&
printf '%s  %s\n' '4cddc3059cba774b27ac9327567bc7260b9104167c0700f01f8baf314510ea4e' '/root/x-ui-multiplier-installer/install-multiplier.sh' | sha256sum -c - && bash /root/x-ui-multiplier-installer/install-multiplier.sh
```

无需 GitHub 账号授权。系统需要 `curl`、`sha256sum` 等常见工具；仅支持 Linux x86_64 和 SQLite。已有面板必须是官方 v3.11.0。定制程序包的 SHA-256 是 `f6edc529e4c42e97df8264e3dc86aea23cf475255992eb30bc649ea4e3a69689`，脚本会在停止服务前校验。脚本不会替换 Xray 内核，也不会改动现有 Vision 客户端配置。

公开 Release 同时提供 `x-ui-v3.11.0-multiplier-source.tar.gz` 对应源码、二进制程序包及校验文件。3x-ui 采用 GPLv3，参见 [LICENSE](LICENSE)。

安装成功后，备份路径会显示在终端，也记录在 `/root/x-ui-multiplier-backup-path`。回退原面板程序：

```bash
systemctl stop x-ui
backup_dir="$(cat /root/x-ui-multiplier-backup-path)"
install -m 755 "$backup_dir/panel-x-ui" /usr/local/x-ui/x-ui
systemctl start x-ui
systemctl is-active x-ui
```

回退程序不会回滚安装后新增的流量数据；完整数据库备份在 `$backup_dir/etc-x-ui`。请先在测试 VPS 验证安装和流量倍率。

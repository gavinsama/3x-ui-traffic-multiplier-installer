#!/usr/bin/env bash
set -Eeuo pipefail

archive='x-ui-v3.11.0-multiplier-linux-amd64.tar.gz'
binary='x-ui-v3.11.0-multiplier-linux-amd64'
archive_sha256='f6edc529e4c42e97df8264e3dc86aea23cf475255992eb30bc649ea4e3a69689'
archive_url='https://github.com/gavinsama/3x-ui-traffic-multiplier-installer/releases/download/v3.11.0-multiplier.1/x-ui-v3.11.0-multiplier-linux-amd64.tar.gz'
official_installer='https://raw.githubusercontent.com/MHSanaei/3x-ui/c621ba9014a6aa21fd7c9ecf45655e44e24ebf13/install.sh'
download_dir='/root/x-ui-multiplier-download'
panel='/usr/local/x-ui/x-ui'
database='/etc/x-ui/x-ui.db'
backup_marker='/root/x-ui-multiplier-backup-path'
backup_dir=''
service_stopped=0

fail() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

on_exit() {
    local status=$?
    if (( status != 0 && service_stopped == 1 )); then
        printf '安装未完成，正在恢复原面板程序和服务...\n' >&2
        if [[ -f "$backup_dir/panel-x-ui" ]]; then
            install -m 755 "$backup_dir/panel-x-ui" "$panel" || true
        fi
        systemctl start x-ui || true
        printf '请检查：systemctl status x-ui --no-pager -l\n' >&2
    fi
}
trap on_exit EXIT

[[ $EUID -eq 0 ]] || fail '请以 root 用户运行。'
[[ $(uname -s) == Linux ]] || fail '只能在 Linux VPS 上运行。'
[[ $(uname -m) == x86_64 ]] || fail '此程序包只支持 x86_64/amd64。'
for required_command in curl sha256sum tar systemctl install cp tr grep; do
    command -v "$required_command" >/dev/null 2>&1 || fail "缺少命令 $required_command；请先按仓库安装说明准备环境。"
done

printf '3x-ui v3.11.0 流量倍率版安装\n'
printf '1) 已安装官方 3.11.0（SQLite）：保留数据并替换面板\n'
printf '2) 全新 VPS（SQLite）：先安装官方 3.11.0，再替换面板\n'
printf '0) 退出\n'
printf '请选择 [0/1/2]：'
IFS= read -r choice || fail '未收到选择。'

case "$choice" in
    0) exit 0 ;;
    1)
        [[ -x "$panel" && -f "$database" ]] || fail '未找到现有面板或 SQLite 数据库；请核对安装状态。'
        ;;
    2)
        [[ ! -e "$panel" && ! -e /etc/x-ui && ! -e /etc/systemd/system/x-ui.service ]] || fail '检测到已有面板或数据，不能使用全新安装；请选 1 或手动检查。'
        ;;
    *) fail '只能选择 0、1 或 2。' ;;
esac

if [[ "$choice" == 1 ]]; then
    current_version="$("$panel" -v | tr -d '\r\n')"
    [[ "$current_version" == 3.11.0 ]] || fail "当前面板版本是 $current_version，本包只能替换官方 3.11.0。"
fi

install -d -m 700 "$download_dir"
printf '正在下载定制程序...\n'
curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
    --output "$download_dir/$archive" "$archive_url"
printf '%s  %s\n' "$archive_sha256" "$download_dir/$archive" | sha256sum -c - || fail '程序包校验失败。'
tar -xzf "$download_dir/$archive" -C "$download_dir"
[[ -s "$download_dir/$binary" ]] || fail '程序包中缺少面板程序。'

if [[ "$choice" == 2 ]]; then
    printf '正在安装官方 3x-ui v3.11.0；请按官方安装程序提示操作...\n'
    curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
        --output "$download_dir/official-install-v3.11.0.sh" "$official_installer"
    bash "$download_dir/official-install-v3.11.0.sh" v3.11.0
fi

if [[ -f /etc/default/x-ui ]] && grep -Eqi '^[[:space:]]*XUI_DB_TYPE[[:space:]]*=[[:space:]]*"?postgres' /etc/default/x-ui; then
    fail '检测到 PostgreSQL 配置；此一键脚本只支持 SQLite。'
fi
[[ -x "$panel" && -f "$database" ]] || fail '官方安装未完成，或未找到 SQLite 数据库。'
current_version="$("$panel" -v | tr -d '\r\n')"
[[ "$current_version" == 3.11.0 ]] || fail "官方安装后的版本是 $current_version，停止替换。"

backup_dir="/root/x-ui-before-multiplier-$(date +%Y%m%d-%H%M%S)-$$"
install -d -m 700 "$backup_dir"
printf '正在停止服务并备份到 %s ...\n' "$backup_dir"
service_stopped=1
systemctl stop x-ui
cp -a /etc/x-ui "$backup_dir/etc-x-ui"
cp -a "$panel" "$backup_dir/panel-x-ui"
[[ -f "$backup_dir/etc-x-ui/x-ui.db" && -s "$backup_dir/panel-x-ui" ]] || fail '备份不完整。'
printf '%s\n' "$backup_dir" > "$backup_marker"

install -m 755 "$download_dir/$binary" "$panel"
systemctl start x-ui
systemctl is-active --quiet x-ui || fail '服务未保持运行。'
installed_version="$("$panel" -v | tr -d '\r\n')"
service_status="$(systemctl is-active x-ui)"
service_stopped=0

printf '安装完成。面板版本：%s；服务：%s\n' "$installed_version" "$service_status"
printf '备份位置：%s\n' "$backup_dir"
printf 'Xray 内核未由定制程序替换；请在面板核对入站、客户端和流量倍率。\n'

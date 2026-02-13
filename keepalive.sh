#!/bin/bash

# 环境变量:
# WORKSPACES - workspace URL 列表, 用逗号分隔

export DISPLAY=:99

# 随机数 (min, max)
rand_range() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 解析 URL 列表
IFS=',' read -ra URLS <<< "$WORKSPACES"
log "共 ${#URLS[@]} 个 workspace"

# 启动 Firefox（保持运行）
log "启动 Firefox..."
firefox-esr -P default --no-remote "about:blank" &
FF_PID=$!
sleep 5

# 获取 Firefox 窗口 ID
get_firefox_window() {
    xdotool search --name "Mozilla Firefox" | head -1
}

# 等待窗口出现
for i in {1..10}; do
    WIN_ID=$(get_firefox_window)
    if [ -n "$WIN_ID" ]; then
        break
    fi
    sleep 1
done

if [ -z "$WIN_ID" ]; then
    log "错误: 无法找到 Firefox 窗口"
    exit 1
fi

log "Firefox 窗口 ID: $WIN_ID"

# 打开新 tab 并访问 URL
open_tab() {
    local url=$1
    # Ctrl+T 打开新 tab
    xdotool windowactivate --sync $WIN_ID key --clearmodifiers ctrl+t
    sleep 1
    # Ctrl+L 聚焦地址栏，输入 URL，回车
    xdotool windowactivate --sync $WIN_ID key --clearmodifiers ctrl+l
    sleep 0.5
    xdotool type --clearmodifiers "$url"
    sleep 0.5
    xdotool key --clearmodifiers Return
}

# 关闭当前 tab
close_tab() {
    # Ctrl+W 关闭当前 tab
    xdotool windowactivate --sync $WIN_ID key --clearmodifiers ctrl+w
}

round=1

while true; do
    log "===== 第 ${round} 轮开始 ====="
    
    for i in "${!URLS[@]}"; do
        url=$(echo "${URLS[$i]}" | xargs)  # trim 空格
        index=$((i + 1))
        
        log "打开 workspace ${index}: ${url}"
        open_tab "$url"
        
        # 停留 4-5 分钟
        stay=$(rand_range 240 300)
        log "停留 ${stay} 秒..."
        sleep $stay
        
        # 关闭 tab
        log "关闭 workspace ${index}"
        close_tab
        sleep 1
        
        # 等待 15-50 秒
        wait_time=$(rand_range 15 50)
        log "等待 ${wait_time} 秒..."
        sleep $wait_time
    done
    
    log "===== 第 ${round} 轮结束 ====="
    echo ""
    ((round++))
done

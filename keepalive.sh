#!/bin/bash

# 环境变量:
# WORKSPACES - workspace URL 列表, 用逗号分隔

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

round=1

while true; do
    log "===== 第 ${round} 轮开始 ====="
    
    for i in "${!URLS[@]}"; do
        url=$(echo "${URLS[$i]}" | xargs)  # trim 空格
        index=$((i + 1))
        
        log "打开 workspace ${index}: ${url}"
        
        firefox-esr "$url" &
        FF_PID=$!
        
        # 停留 4-5 分钟
        stay=$(rand_range 240 300)
        log "停留 ${stay} 秒..."
        sleep $stay
        
        # 关闭 Firefox
        log "关闭 workspace ${index}"
        kill $FF_PID 2>/dev/null
        wait $FF_PID 2>/dev/null
        
        # 等待 15-50 秒
        wait_time=$(rand_range 15 50)
        log "等待 ${wait_time} 秒..."
        sleep $wait_time
    done
    
    log "===== 第 ${round} 轮结束 ====="
    echo ""
    ((round++))
done

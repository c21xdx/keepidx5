#!/bin/bash

# 环境变量:
# PROXY - SOCKS5 代理地址 (可选), 格式: host:port
# WORKSPACES - workspace URL 列表, 用逗号分隔

# 启动虚拟显示器
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
sleep 2

# 启动 VNC 服务
if [ -n "$VNC_PASSWORD" ]; then
    x11vnc -display :99 -forever -passwd "$VNC_PASSWORD" -shared -rfbport 5900 &
    echo "VNC 密码已设置"
else
    x11vnc -display :99 -forever -nopw -shared -rfbport 5900 &
    echo "警告: 未设置 VNC 密码"
fi
sleep 1

# 启动 noVNC (Web 访问)
websockify --web /usr/share/novnc 6080 localhost:5900 &
sleep 1

echo "============================================"
echo "noVNC: http://localhost:6080/vnc.html"
echo "============================================"
echo ""
echo "配置:"
echo "  VNC_PASSWORD: ${VNC_PASSWORD:+***}"
echo "  PROXY: ${PROXY:-(未设置)}"
echo "  WORKSPACES: ${WORKSPACES:-(未设置)}"
echo "============================================"

# 配置 Firefox 代理
setup_firefox_proxy() {
    local profile_dir="/root/.mozilla/firefox"
    
    if [ -n "$PROXY" ]; then
        echo "配置 SOCKS5 代理: $PROXY"
        
        PROXY_HOST=$(echo "$PROXY" | cut -d':' -f1)
        PROXY_PORT=$(echo "$PROXY" | cut -d':' -f2)
        
        mkdir -p "$profile_dir"
        
        # 初始化 profile
        if [ ! -f "$profile_dir/profiles.ini" ]; then
            firefox-esr --headless --screenshot /tmp/init.png "about:blank" 2>/dev/null &
            sleep 3
            pkill -f firefox
            sleep 1
        fi
        
        local default_profile=$(find "$profile_dir" -maxdepth 1 -type d -name "*.default*" | head -1)
        
        if [ -n "$default_profile" ]; then
            cat > "$default_profile/user.js" << EOF
// SOCKS5 Proxy
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "$PROXY_HOST");
user_pref("network.proxy.socks_port", $PROXY_PORT);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
EOF
            echo "代理配置已写入: $default_profile/user.js"
        fi
    fi
}

# 检查配置
if [ -z "$WORKSPACES" ]; then
    echo ""
    echo "错误: 未设置 WORKSPACES 环境变量"
    echo "示例: -e WORKSPACES=\"https://idx.google.com/ws1,https://idx.google.com/ws2\""
    echo ""
    echo "容器将保持运行，你可以通过 noVNC 访问桌面"
    # 保持容器运行
    tail -f /dev/null
fi

# 检查是否已登录
if [ ! -d "/root/.mozilla/firefox" ] || [ -z "$(ls -A /root/.mozilla/firefox 2>/dev/null | grep -v 'profiles.ini')" ]; then
    echo ""
    echo "首次运行，请通过 noVNC 手动登录 Google 账号"
    
    setup_firefox_proxy
    
    echo "启动 Firefox..."
    firefox-esr https://idx.google.com/ &
    
    echo "登录完成后，关闭 Firefox 窗口，保活脚本将自动启动"
    wait
else
    setup_firefox_proxy
fi

# 启动保活脚本
echo "启动保活脚本..."
exec /app/keepalive.sh

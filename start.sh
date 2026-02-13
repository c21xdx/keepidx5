#!/bin/bash

# 环境变量:
# VNC_PASSWORD - VNC 访问密码 (可选)
# PROXY - SOCKS5 代理地址 (可选), 格式: host:port
# WORKSPACES - workspace URL 列表, 用逗号分隔

export DISPLAY=:99

# 启动虚拟显示器
Xvfb :99 -screen 0 1280x720x24 &
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

# 检查配置
if [ -z "$WORKSPACES" ]; then
    echo ""
    echo "错误: 未设置 WORKSPACES 环境变量"
    echo "示例: -e WORKSPACES=\"https://idx.google.com/ws1,https://idx.google.com/ws2\""
    echo ""
    echo "容器将保持运行，你可以通过 noVNC 访问桌面"
    tail -f /dev/null
fi

# 配置 Firefox 代理和首选项
setup_firefox() {
    local profile_dir="/root/.mozilla/firefox"
    
    # 初始化 profile（如果不存在）
    if [ ! -f "$profile_dir/profiles.ini" ]; then
        echo "初始化 Firefox profile..."
        firefox-esr --headless -CreateProfile "default /root/.mozilla/firefox/default" 2>/dev/null
        sleep 2
    fi
    
    local default_profile="$profile_dir/default"
    mkdir -p "$default_profile"
    
    # 写入配置
    cat > "$default_profile/user.js" << 'EOF'
// 禁用首次运行页面
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
// 启动时打开空白页
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
// 禁用恢复会话
user_pref("browser.sessionstore.resume_from_crash", false);
EOF
    
    # 添加代理配置
    if [ -n "$PROXY" ]; then
        echo "配置 SOCKS5 代理: $PROXY"
        PROXY_HOST=$(echo "$PROXY" | cut -d':' -f1)
        PROXY_PORT=$(echo "$PROXY" | cut -d':' -f2)
        
        cat >> "$default_profile/user.js" << EOF
// SOCKS5 Proxy
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "$PROXY_HOST");
user_pref("network.proxy.socks_port", $PROXY_PORT);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
EOF
    fi
    
    echo "Firefox 配置完成"
}

# 等待登录成功
wait_for_login() {
    local profile_dir="/root/.mozilla/firefox/default"
    local cookies_file="$profile_dir/cookies.sqlite"
    
    echo ""
    echo "请通过 noVNC 完成 Google 登录"
    echo "登录成功后，脚本将自动开始保活"
    echo ""
    
    # 启动 Firefox 用于登录
    firefox-esr -P default --no-remote "https://idx.google.com/" &
    local ff_pid=$!
    
    # 等待 cookies 文件出现且有内容
    while true; do
        if [ -f "$cookies_file" ]; then
            local size=$(stat -c%s "$cookies_file" 2>/dev/null || echo 0)
            # cookies.sqlite 大于 50KB 说明有登录数据
            if [ "$size" -gt 50000 ]; then
                echo ""
                echo "检测到登录成功！"
                sleep 3
                break
            fi
        fi
        sleep 5
    done
    
    # 关闭登录用的浏览器
    kill $ff_pid 2>/dev/null
    wait $ff_pid 2>/dev/null
    sleep 2
}

# 主流程
setup_firefox

# 检查是否已登录
profile_dir="/root/.mozilla/firefox/default"
cookies_file="$profile_dir/cookies.sqlite"

if [ -f "$cookies_file" ] && [ $(stat -c%s "$cookies_file" 2>/dev/null || echo 0) -gt 50000 ]; then
    echo "检测到已有登录状态"
else
    wait_for_login
fi

# 启动保活脚本
echo "启动保活脚本..."
exec /app/keepalive.sh

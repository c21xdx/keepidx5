# 开发笔记

## 项目背景

Firebase Studio（原 Project IDX）的 workspace 长时间不活跃会自动休眠。本项目通过 Docker 容器定期访问 workspace 来保持活跃。

## 技术选型

### 浏览器选择

| 方案 | 优点 | 缺点 |
|------|------|------|
| Puppeteer headless | 轻量 | 易被 Google 风控检测 |
| Chromium + Xvfb | 指纹正常 | 内存较高 |
| **Firefox + Xvfb** | 指纹正常，内存较低 | 与用户平时用的浏览器不同 |

最终选择 Firefox，因为：
- 资源限制（0.5 CPU, 1GB RAM）
- 不使用 headless，避免风控

### Tab 控制方案

| 方案 | 说明 |
|------|------|
| 每次启动新浏览器 | 简单，但消耗资源 |
| **保持浏览器 + xdotool** | 省资源，更像真人操作 |

选择方案 B，使用 xdotool 发送键盘快捷键控制 tab。

## 关键实现

### 1. 登录检测

通过监测 Firefox 的 `cookies.sqlite` 文件大小：

```bash
# cookies.sqlite > 50KB 说明有登录数据
if [ "$size" -gt 50000 ]; then
    echo "检测到登录成功"
fi
```

### 2. xdotool Tab 控制

```bash
# 打开新 tab
xdotool key ctrl+t

# 输入 URL
xdotool key ctrl+l
xdotool type "$url"
xdotool key Return

# 关闭 tab
xdotool key ctrl+w
```

### 3. Firefox 配置优化

通过 `user.js` 禁用不必要的功能：

```javascript
// 禁用首次运行页面
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);
// 启动时打开空白页
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
```

### 4. SOCKS5 代理

```javascript
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "host");
user_pref("network.proxy.socks_port", port);
user_pref("network.proxy.socks_remote_dns", true);  // DNS 也走代理
```

## 时间参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 停留时间 | 240-300秒 | 4-5 分钟 |
| 间隔时间 | 15-50秒 | 避免太规律 |
| 一轮时间 | ~30分钟 | 5个 workspace |

## 未实现的方案

### 休眠时段

考虑过在凌晨 2-6 点降低访问频率，但担心 workspace 会休眠，最终决定 24 小时保持一致频率。

### 模拟交互

考虑过模拟鼠标移动、点击等操作，但测试发现仅停留页面即可保活，无需额外交互。

## 注意事项

1. **IP 稳定性** - 频繁更换 IP 可能触发 Google 安全验证
2. **登录有效期** - Google 登录态可能数周后过期
3. **内存使用** - Firefox 运行时约占用 300-400MB

## 文件说明

```
├── Dockerfile       # 容器镜像（Debian + Firefox + Xvfb + noVNC + xdotool）
├── start.sh         # 启动脚本（VNC/noVNC + Firefox 配置 + 登录检测）
├── keepalive.sh     # 保活循环（xdotool 控制 tab）
├── README.md        # 使用说明
└── NOTE.md          # 开发笔记
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `WORKSPACES` | ✅ | URL 列表，逗号分隔 |
| `VNC_PASSWORD` | 建议 | noVNC 访问密码 |
| `PROXY` | 可选 | SOCKS5 代理 host:port |

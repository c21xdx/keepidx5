# Firebase Studio Workspace Keepalive

保持 Firebase Studio（原 Project IDX）workspace 活跃的 Docker 容器。

## 原理

Firebase Studio 的 workspace 长时间不活跃会自动休眠。本项目通过容器定期访问 workspace 页面来保持活跃。

- 使用 Firefox 浏览器访问 workspace
- 每个 workspace 停留 4-5 分钟后关闭
- 间隔 15-50 秒后访问下一个
- 约 30 分钟完成一轮，每个 workspace 每小时刷新 2 次
- 通过 noVNC 提供 Web 界面，用于首次 Google 登录
- 支持 SOCKS5 代理

## 资源需求

- CPU: 0.5 核
- 内存: 1GB

## 文件说明

```
├── Dockerfile       # 容器镜像定义
├── start.sh         # 启动脚本
├── keepalive.sh     # 保活循环脚本
└── README.md
```

## 环境变量

| 变量 | 说明 | 必填 | 示例 |
|------|------|------|------|
| `WORKSPACES` | workspace URL 列表，逗号分隔 | ✅ | `https://idx.google.com/ws1,https://idx.google.com/ws2` |
| `VNC_PASSWORD` | noVNC 访问密码 | 建议 | `your_password` |
| `PROXY` | SOCKS5 代理地址 | 可选 | `127.0.0.1:1080` |

## 使用方法

### 1. 构建镜像

```bash
docker build -t firebase-keepalive .
```

### 2. 运行容器

```bash
docker run -d \
  -p 6080:6080 \
  -v firebase-profile:/root/.mozilla \
  -e WORKSPACES="https://idx.google.com/ws1,https://idx.google.com/ws2,https://idx.google.com/ws3" \
  -e PROXY="127.0.0.1:1080" \
  -e VNC_PASSWORD="your_password" \
  --name keepalive \
  firebase-keepalive
```

参数说明：
- `-p 6080:6080` - noVNC Web 端口
- `-v firebase-profile:/root/.mozilla` - 持久化 Firefox 登录状态
- `-e WORKSPACES` - workspace URL 列表
- `-e PROXY` - SOCKS5 代理（可选）
- `-e VNC_PASSWORD` - noVNC 访问密码（可选，建议设置）

### 3. 首次登录

1. 浏览器访问 `http://<服务器IP>:6080/vnc.html`
2. 点击「Connect」连接到虚拟桌面
3. 在 Firefox 中完成 Google 账号登录
4. 登录成功后，关闭 Firefox 窗口
5. 保活脚本将自动启动

### 4. 查看日志

```bash
docker logs -f keepalive
```

输出示例：
```
[2024-01-01 12:00:00] 共 5 个 workspace
[2024-01-01 12:00:00] ===== 第 1 轮开始 =====
[2024-01-01 12:00:00] 打开 workspace 1: https://idx.google.com/xxx
[2024-01-01 12:00:00] 停留 267 秒...
[2024-01-01 12:04:27] 关闭 workspace 1
[2024-01-01 12:04:27] 等待 35 秒...
...
```

### 5. 修改配置

修改环境变量后重新创建容器：

```bash
docker stop keepalive && docker rm keepalive

docker run -d \
  -p 6080:6080 \
  -v firebase-profile:/root/.mozilla \
  -e WORKSPACES="https://idx.google.com/new-ws1,https://idx.google.com/new-ws2" \
  --name keepalive \
  firebase-keepalive
```

### 6. 管理命令

```bash
# 停止
docker stop keepalive

# 启动
docker start keepalive

# 重启
docker restart keepalive

# 删除容器（保留登录状态）
docker rm keepalive

# 删除登录状态
docker volume rm firebase-profile
```

## 重新登录

如果 Google 登录过期：

```bash
# 停止并删除容器
docker stop keepalive && docker rm keepalive

# 清除登录状态
docker volume rm firebase-profile

# 重新运行，按照「首次登录」步骤操作
```

## 自定义参数

修改 `keepalive.sh` 中的参数：

```bash
# 停留时间范围（秒）
stay=$(rand_range 240 300)    # 4-5 分钟

# 等待时间范围（秒）  
wait_time=$(rand_range 15 50) # 15-50 秒
```

## 注意事项

1. **IP 稳定性** - 建议使用固定 IP，频繁更换 IP 可能触发 Google 安全验证
2. **登录有效期** - Google 登录态可能数周后过期，届时需重新登录
3. **noVNC 安全** - 生产环境必须设置 `VNC_PASSWORD`
4. **时区** - 容器使用 UTC 时区，日志时间可能与本地时间不同

## Docker Compose

```yaml
version: '3'
services:
  keepalive:
    build: .
    ports:
      - "6080:6080"
    volumes:
      - firefox-profile:/root/.mozilla
    environment:
      - WORKSPACES=https://idx.google.com/ws1,https://idx.google.com/ws2
      - PROXY=127.0.0.1:1080
      - VNC_PASSWORD=your_password
    restart: unless-stopped

volumes:
  firefox-profile:
```

## License

MIT

FROM debian:bookworm-slim

# 安装必要组件
RUN apt-get update && apt-get install -y \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    xdotool \
    procps \
    fonts-wqy-zenhei \
    fonts-noto-color-emoji \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY start.sh .
COPY keepalive.sh .

RUN chmod +x start.sh keepalive.sh

# Firefox profile 持久化
VOLUME /root/.mozilla

# noVNC 端口
EXPOSE 6080

# 环境变量
ENV VNC_PASSWORD=""
ENV PROXY=""
ENV WORKSPACES=""

CMD ["/app/start.sh"]

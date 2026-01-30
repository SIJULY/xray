#!/bin/bash
set -e

echo "🔧 安装 Dante (SOCKS5) 和 Squid (HTTP 代理) [免密模式]..."

# 更新并安装软件 (不需要 apache2-utils 了，因为不需要 htpasswd)
apt update
apt install -y dante-server squid

# ==========================================
# 配置 Dante (SOCKS5) - 无密码
# ==========================================
echo "✅ 配置 Dante SOCKS5 (免密)..."

# 获取主要网卡 IP
SERVER_IP=$(hostname -I | awk '{print $1}')

cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log

# 监听端口
internal: 0.0.0.0 port = 6000
external: $SERVER_IP

# 认证方式：none (无密码)
method: none

user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    method: none
    log: connect disconnect error
}
EOF

# ==========================================
# 配置 Squid (HTTP) - 无密码
# ==========================================
echo "✅ 配置 Squid HTTP 代理 (免密)..."

# 备份原始配置
mv /etc/squid/squid.conf /etc/squid/squid.conf.bak || true

# 生成新配置
# http_access allow all 表示允许任何人连接
cat > /etc/squid/squid.conf <<EOF
http_port 7000

# 定义访问控制列表 (允许所有 IP)
acl all_src src 0.0.0.0/0

# 允许所有访问
http_access allow all_src

# 关闭缓存
cache deny all
access_log /var/log/squid/access.log
EOF

# ==========================================
# 启动服务
# ==========================================
echo "✅ 启动服务并设置开机自启..."

systemctl restart danted
systemctl enable danted

systemctl restart squid || {
    echo "❌ Squid 启动失败，请查看日志："
    journalctl -xeu squid.service | tail -n 30
    exit 1
}
systemctl enable squid

# ==========================================
# 防火墙配置
# ==========================================
if command -v ufw >/dev/null && ufw status | grep -q active; then
    echo "✅ 开放防火墙端口 6000 和 7000..."
    ufw allow 6000/tcp
    ufw allow 7000/tcp
else
    echo "⚠️ 未检测到已启用的 UFW 防火墙，请手动放行端口 6000 和 7000"
fi

# ==========================================
# 完成提示
# ==========================================
echo "🎉 安装完成！(无密码模式)"
echo "SOCKS5 地址: $SERVER_IP:6000"
echo "HTTP 地址:  $SERVER_IP:7000"
echo "⚠️  注意：当前代理对外完全开放，请注意安全风险！"

#!/bin/bash

# SSL 证书自动化配置脚本
# 使用 Let's Encrypt 免费 SSL 证书

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
DOMAIN="www.gaopeng.site"
EMAIL="admin@gaopeng.site"  # 请修改为您的邮箱

echo -e "${BLUE}🔐 开始配置 SSL 证书${NC}"

# 检查是否为 root 或有 sudo 权限
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ 正在以 root 用户运行${NC}"
    elif ! sudo -n true 2>/dev/null; then
        echo -e "${RED}❌ 需要 sudo 权限${NC}"
        exit 1
    fi
}

# 安装 Certbot
install_certbot() {
    echo -e "${BLUE}📦 安装 Certbot...${NC}"

    # 检测系统类型
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        sudo yum install -y certbot python3-certbot-nginx
    else
        echo -e "${RED}❌ 不支持的系统类型${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Certbot 安装完成${NC}"
}

# 检查域名解析
check_dns() {
    echo -e "${BLUE}🌐 检查域名解析...${NC}"

    DOMAINS=("gaopeng.site" "www.gaopeng.site")

    for domain in "${DOMAINS[@]}"; do
        echo -e "检查 $domain..."
        if nslookup $domain > /dev/null 2>&1; then
            IP=$(dig +short $domain | tail -1)
            echo -e "${GREEN}✅ $domain 解析到 IP: $IP${NC}"
        else
            echo -e "${RED}❌ $domain 无法解析${NC}"
            echo -e "${YELLOW}请确保域名已正确指向服务器 IP${NC}"
            exit 1
        fi
    done
}

# 检查 Nginx 配置
check_nginx() {
    echo -e "${BLUE}🔍 检查 Nginx 配置...${NC}"

    if ! sudo nginx -t; then
        echo -e "${RED}❌ Nginx 配置有误${NC}"
        exit 1
    fi

    # 确保 Nginx 正在运行
    if ! systemctl is-active --quiet nginx; then
        sudo systemctl start nginx
    fi

    echo -e "${GREEN}✅ Nginx 配置正常${NC}"
}

# 获取 SSL 证书
obtain_certificate() {
    echo -e "${BLUE}🔐 获取 SSL 证书...${NC}"

    # 检查是否已有证书
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        echo -e "${YELLOW}⚠️ 证书已存在，是否要续期？(y/N)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo certbot renew --nginx
        else
            echo -e "${GREEN}✅ 使用现有证书${NC}"
            return
        fi
    else
        # 获取新证书
        sudo certbot --nginx \
            -d gaopeng.site \
            -d www.gaopeng.site \
            --email $EMAIL \
            --agree-tos \
            --no-eff-email \
            --redirect
    fi

    echo -e "${GREEN}✅ SSL 证书配置完成${NC}"
}

# 设置自动续期
setup_auto_renewal() {
    echo -e "${BLUE}🔄 配置自动续期...${NC}"

    # 创建续期脚本
    sudo tee /usr/local/bin/certbot-renewal.sh > /dev/null << 'EOF'
#!/bin/bash

# SSL 证书自动续期脚本
LOG_FILE="/var/log/certbot-renewal.log"

echo "$(date): 开始检查证书续期" >> $LOG_FILE

# 续期证书
if certbot renew --quiet --nginx >> $LOG_FILE 2>&1; then
    echo "$(date): 证书续期检查完成" >> $LOG_FILE

    # 重新加载 Nginx
    systemctl reload nginx
    echo "$(date): Nginx 已重新加载" >> $LOG_FILE
else
    echo "$(date): 证书续期失败" >> $LOG_FILE
    # 这里可以添加邮件通知等功能
fi

# 清理旧日志（保留最近30天）
find /var/log/letsencrypt/ -name "*.log" -type f -mtime +30 -delete
EOF

    sudo chmod +x /usr/local/bin/certbot-renewal.sh

    # 添加到 crontab（每周检查一次）
    CRON_JOB="0 2 * * 1 /usr/local/bin/certbot-renewal.sh"

    # 检查是否已存在
    if ! crontab -l 2>/dev/null | grep -q "certbot-renewal.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
        echo -e "${GREEN}✅ 自动续期任务已添加${NC}"
    else
        echo -e "${YELLOW}⚠️ 自动续期任务已存在${NC}"
    fi

    # 创建日志目录
    sudo mkdir -p /var/log
    sudo touch /var/log/certbot-renewal.log

    echo -e "${GREEN}✅ 自动续期配置完成${NC}"
}

# 验证 SSL 配置
verify_ssl() {
    echo -e "${BLUE}🔍 验证 SSL 配置...${NC}"

    # 等待几秒让配置生效
    sleep 5

    # 检查 HTTPS 连接
    if curl -sf "https://$DOMAIN" > /dev/null; then
        echo -e "${GREEN}✅ HTTPS 连接正常${NC}"
    else
        echo -e "${RED}❌ HTTPS 连接失败${NC}"
        echo -e "${YELLOW}请检查防火墙设置和域名解析${NC}"
    fi

    # 显示证书信息
    echo -e "${BLUE}📋 证书信息：${NC}"
    sudo certbot certificates
}

# 创建 SSL 状态检查脚本
create_ssl_check() {
    echo -e "${BLUE}📝 创建 SSL 状态检查脚本...${NC}"

    sudo tee /usr/local/bin/ssl-check.sh > /dev/null << 'EOF'
#!/bin/bash

# SSL 证书状态检查脚本

DOMAIN="www.gaopeng.site"
DAYS_WARNING=30

echo "=== SSL 证书状态检查 ==="
echo "域名: $DOMAIN"
echo "检查时间: $(date)"
echo ""

# 检查证书过期时间
if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    EXPIRY=$(openssl x509 -noout -dates -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" | grep "notAfter" | cut -d= -f2)
    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

    echo "证书过期时间: $EXPIRY"
    echo "剩余天数: $DAYS_LEFT 天"

    if [[ $DAYS_LEFT -lt $DAYS_WARNING ]]; then
        echo "⚠️  警告: 证书将在 $DAYS_LEFT 天后过期！"
    else
        echo "✅ 证书状态正常"
    fi
else
    echo "❌ 未找到证书文件"
fi

echo ""
echo "=== 完整证书信息 ==="
certbot certificates
EOF

    sudo chmod +x /usr/local/bin/ssl-check.sh

    echo -e "${GREEN}✅ SSL 检查脚本已创建: /usr/local/bin/ssl-check.sh${NC}"
}

# 主函数
main() {
    check_sudo
    install_certbot
    check_dns
    check_nginx
    obtain_certificate
    setup_auto_renewal
    verify_ssl
    create_ssl_check

    echo ""
    echo -e "${GREEN}🎉 SSL 配置完成！${NC}"
    echo -e "${BLUE}📋 可用命令：${NC}"
    echo -e "- 检查证书状态: ${YELLOW}sudo /usr/local/bin/ssl-check.sh${NC}"
    echo -e "- 手动续期证书: ${YELLOW}sudo certbot renew --nginx${NC}"
    echo -e "- 查看所有证书: ${YELLOW}sudo certbot certificates${NC}"
    echo -e "- 测试续期: ${YELLOW}sudo certbot renew --dry-run${NC}"
    echo ""
    echo -e "${GREEN}🌐 网站现在可以通过 HTTPS 访问: https://$DOMAIN${NC}"
}

# 错误处理
trap 'echo -e "${RED}❌ SSL 配置过程中发生错误${NC}"; exit 1' ERR

# 执行主函数
main "$@"
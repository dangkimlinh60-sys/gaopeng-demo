#!/bin/bash

# 生产环境部署脚本 - www.gaopeng.site
# 使用方法: ./production-deploy.sh

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
DOMAIN="www.gaopeng.site"
APP_NAME="gaopeng-demo"
APP_DIR="/var/www/$APP_NAME"
BACKUP_DIR="/var/backups/$APP_NAME"
NGINX_CONFIG="/etc/nginx/sites-available/$APP_NAME"

echo -e "${BLUE}🚀 开始生产环境部署到 $DOMAIN${NC}"

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ 请不要使用 root 用户运行此脚本${NC}"
   exit 1
fi

# 检查系统依赖
check_dependencies() {
    echo -e "${BLUE}🔍 检查系统依赖...${NC}"

    commands=("git" "node" "npm" "nginx" "ufw")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}❌ $cmd 未安装${NC}"
            echo -e "${YELLOW}请先安装: sudo apt update && sudo apt install -y $cmd${NC}"
            exit 1
        fi
    done

    # 检查 Node.js 版本
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ $NODE_VERSION -lt 18 ]]; then
        echo -e "${RED}❌ Node.js 版本过低 (当前: $(node -v))，需要 18+${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ 所有依赖检查通过${NC}"
}

# 创建应用目录
setup_directories() {
    echo -e "${BLUE}📁 设置目录结构...${NC}"

    sudo mkdir -p $APP_DIR
    sudo mkdir -p $BACKUP_DIR
    sudo mkdir -p /etc/nginx/ssl
    sudo chown -R $USER:$USER $APP_DIR

    echo -e "${GREEN}✅ 目录创建完成${NC}"
}

# 备份现有部署
backup_current() {
    if [[ -d "$APP_DIR/.next" ]]; then
        echo -e "${BLUE}💾 备份当前部署...${NC}"

        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        sudo cp -r $APP_DIR $BACKUP_DIR/backup_$TIMESTAMP

        echo -e "${GREEN}✅ 备份完成: $BACKUP_DIR/backup_$TIMESTAMP${NC}"
    fi
}

# 部署代码
deploy_code() {
    echo -e "${BLUE}📦 部署应用代码...${NC}"

    # 如果目录不存在，克隆仓库
    if [[ ! -d "$APP_DIR/.git" ]]; then
        git clone https://github.com/dangkimlinh60-sys/gaopeng-demo.git $APP_DIR
    else
        cd $APP_DIR
        git pull origin main
    fi

    cd $APP_DIR

    # 安装依赖
    echo -e "${BLUE}📦 安装依赖...${NC}"
    npm ci --only=production

    # 构建应用
    echo -e "${BLUE}🔧 构建应用...${NC}"
    npm run build

    echo -e "${GREEN}✅ 代码部署完成${NC}"
}

# 配置 PM2 进程管理
setup_pm2() {
    echo -e "${BLUE}⚙️ 配置 PM2 进程管理...${NC}"

    # 安装 PM2（如果未安装）
    if ! command -v pm2 &> /dev/null; then
        sudo npm install -g pm2
    fi

    # 创建 PM2 配置文件
    cat > $APP_DIR/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$APP_NAME',
    script: './server.js',
    cwd: '$APP_DIR/.next/standalone',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      HOSTNAME: '0.0.0.0'
    },
    error_file: '/var/log/pm2/$APP_NAME-error.log',
    out_file: '/var/log/pm2/$APP_NAME-out.log',
    log_file: '/var/log/pm2/$APP_NAME.log',
    time: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G'
  }]
};
EOF

    # 创建日志目录
    sudo mkdir -p /var/log/pm2
    sudo chown -R $USER:$USER /var/log/pm2

    # 启动应用
    cd $APP_DIR
    pm2 delete $APP_NAME 2>/dev/null || true
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup | tail -1 | sudo bash

    echo -e "${GREEN}✅ PM2 配置完成${NC}"
}

# 配置 Nginx
setup_nginx() {
    echo -e "${BLUE}🌐 配置 Nginx...${NC}"

    # 创建 Nginx 配置
    sudo tee $NGINX_CONFIG > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN gaopeng.site;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN gaopeng.site;

    # SSL 配置（稍后通过 Certbot 自动添加）

    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    # 主要代理配置
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # 静态资源缓存
    location /_next/static/ {
        proxy_pass http://127.0.0.1:3000;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # 图片缓存
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
        proxy_pass http://127.0.0.1:3000;
        add_header Cache-Control "public, max-age=86400";
    }

    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # 启用站点
    sudo ln -sf $NGINX_CONFIG /etc/nginx/sites-enabled/

    # 删除默认配置（如果存在）
    sudo rm -f /etc/nginx/sites-enabled/default

    # 测试配置
    sudo nginx -t

    # 重启 Nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx

    echo -e "${GREEN}✅ Nginx 配置完成${NC}"
}

# 配置防火墙
setup_firewall() {
    echo -e "${BLUE}🔥 配置防火墙...${NC}"

    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow 80
    sudo ufw allow 443

    echo -e "${GREEN}✅ 防火墙配置完成${NC}"
}

# 主函数
main() {
    check_dependencies
    setup_directories
    backup_current
    deploy_code
    setup_pm2
    setup_nginx
    setup_firewall

    echo ""
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo -e "${BLUE}📋 接下来的步骤：${NC}"
    echo -e "1. 配置 SSL 证书: ${YELLOW}sudo certbot --nginx -d $DOMAIN -d gaopeng.site${NC}"
    echo -e "2. 检查应用状态: ${YELLOW}pm2 status${NC}"
    echo -e "3. 查看应用日志: ${YELLOW}pm2 logs $APP_NAME${NC}"
    echo -e "4. 访问网站: ${YELLOW}http://$DOMAIN${NC}"
    echo ""
    echo -e "${GREEN}✨ 部署脚本执行完成！${NC}"
}

# 错误处理
trap 'echo -e "${RED}❌ 部署过程中发生错误${NC}"; exit 1' ERR

# 执行主函数
main "$@"
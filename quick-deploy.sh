#!/bin/bash

# 快速启动脚本 - 一键上传并部署到服务器
# 使用方法: ./quick-deploy.sh [服务器IP] [用户名]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
SERVER_IP="${1:-}"
USERNAME="${2:-root}"
PROJECT_NAME="gaopeng-demo"

show_usage() {
    echo "用法: $0 [服务器IP] [用户名]"
    echo ""
    echo "示例:"
    echo "  $0 192.168.1.100 ubuntu"
    echo "  $0 45.76.123.45 user"
    echo ""
    echo "如果不提供参数，脚本将提示您输入"
}

# 获取服务器信息
get_server_info() {
    if [[ -z "$SERVER_IP" ]]; then
        echo -e "${BLUE}请输入服务器IP地址:${NC}"
        read -r SERVER_IP
    fi

    if [[ -z "$USERNAME" ]] || [[ "$USERNAME" == "root" ]]; then
        echo -e "${BLUE}请输入服务器用户名 (默认: ubuntu):${NC}"
        read -r input_username
        USERNAME="${input_username:-ubuntu}"
    fi

    echo -e "${GREEN}✅ 服务器信息:${NC}"
    echo -e "  IP: $SERVER_IP"
    echo -e "  用户: $USERNAME"
    echo ""
}

# 检查本地文件
check_local_files() {
    echo -e "${BLUE}🔍 检查本地文件...${NC}"

    required_files=(
        "production-deploy.sh"
        "ssl-setup.sh"
        "monitor.sh"
        "package.json"
        "next.config.ts"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}❌ 缺少必要文件: $file${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}✅ 本地文件检查完成${NC}"
}

# 测试服务器连接
test_connection() {
    echo -e "${BLUE}🔌 测试服务器连接...${NC}"

    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$USERNAME@$SERVER_IP" exit 2>/dev/null; then
        echo -e "${GREEN}✅ 服务器连接正常${NC}"
    else
        echo -e "${RED}❌ 无法连接到服务器${NC}"
        echo -e "${YELLOW}请检查:${NC}"
        echo -e "  - 服务器IP是否正确"
        echo -e "  - 用户名是否正确"
        echo -e "  - SSH密钥是否已配置"
        echo -e "  - 服务器防火墙设置"
        exit 1
    fi
}

# 上传项目文件
upload_project() {
    echo -e "${BLUE}📦 上传项目文件到服务器...${NC}"

    # 创建临时排除文件
    cat > .rsync-exclude << EOF
.git/
node_modules/
.next/
*.log
.DS_Store
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF

    # 使用 rsync 上传文件
    rsync -avz --progress \
        --exclude-from=.rsync-exclude \
        --delete \
        ./ "$USERNAME@$SERVER_IP:~/$PROJECT_NAME/"

    # 清理临时文件
    rm -f .rsync-exclude

    echo -e "${GREEN}✅ 文件上传完成${NC}"
}

# 在服务器上执行部署
deploy_on_server() {
    echo -e "${BLUE}🚀 在服务器上执行部署...${NC}"

    ssh "$USERNAME@$SERVER_IP" << EOF
        set -e
        cd ~/$PROJECT_NAME

        echo "设置文件权限..."
        chmod +x production-deploy.sh ssl-setup.sh monitor.sh

        echo "开始生产环境部署..."
        ./production-deploy.sh

        echo "配置SSL证书..."
        ./ssl-setup.sh

        echo "设置监控任务..."
        (crontab -l 2>/dev/null | grep -v "monitor.sh"; echo "*/5 * * * * $(pwd)/monitor.sh check") | crontab -

        echo "运行健康检查..."
        ./monitor.sh check

        echo "部署完成！"
EOF

    echo -e "${GREEN}✅ 服务器部署完成${NC}"
}

# 验证部署
verify_deployment() {
    echo -e "${BLUE}🔍 验证部署状态...${NC}"

    # 检查HTTP访问
    if curl -s -I "http://www.gaopeng.site" | grep -q "301\|302"; then
        echo -e "${GREEN}✅ HTTP重定向正常${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTP访问可能有问题${NC}"
    fi

    # 检查HTTPS访问
    if curl -s -I "https://www.gaopeng.site" | grep -q "200"; then
        echo -e "${GREEN}✅ HTTPS访问正常${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS访问可能有问题（SSL证书可能还在配置中）${NC}"
    fi

    echo -e "${GREEN}🎉 部署验证完成！${NC}"
}

# 显示后续步骤
show_next_steps() {
    echo ""
    echo -e "${BLUE}📋 后续步骤和管理命令:${NC}"
    echo ""
    echo -e "${YELLOW}1. 连接到服务器:${NC}"
    echo -e "   ssh $USERNAME@$SERVER_IP"
    echo ""
    echo -e "${YELLOW}2. 查看服务状态:${NC}"
    echo -e "   cd ~/$PROJECT_NAME && ./monitor.sh check"
    echo ""
    echo -e "${YELLOW}3. 查看应用日志:${NC}"
    echo -e "   pm2 logs gaopeng-demo"
    echo ""
    echo -e "${YELLOW}4. 重启应用:${NC}"
    echo -e "   pm2 restart gaopeng-demo"
    echo ""
    echo -e "${YELLOW}5. 更新代码:${NC}"
    echo -e "   cd ~/$PROJECT_NAME && git pull && npm run build && pm2 restart gaopeng-demo"
    echo ""
    echo -e "${YELLOW}6. 查看SSL证书状态:${NC}"
    echo -e "   sudo certbot certificates"
    echo ""
    echo -e "${GREEN}🌐 访问您的网站: https://www.gaopeng.site${NC}"
}

# 主函数
main() {
    echo -e "${BLUE}🚀 Gaopeng Demo 一键部署脚本${NC}"
    echo ""

    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi

    get_server_info
    check_local_files
    test_connection
    upload_project
    deploy_on_server
    verify_deployment
    show_next_steps

    echo ""
    echo -e "${GREEN}🎉 部署完成！网站应该可以通过 https://www.gaopeng.site 访问${NC}"
}

# 错误处理
trap 'echo -e "${RED}❌ 部署过程中发生错误${NC}"; exit 1' ERR

# 执行主函数
main "$@"
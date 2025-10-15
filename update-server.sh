#!/bin/bash

# 服务器自动更新脚本
# 从GitHub拉取最新代码并重新部署

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 开始更新服务器代码...${NC}"

# 检查当前目录
if [[ ! -f "package.json" ]] || [[ ! -f "next.config.ts" ]]; then
    echo -e "${RED}❌ 错误：请在项目根目录下运行此脚本${NC}"
    echo -e "${YELLOW}提示：请确保在包含 package.json 的目录中执行${NC}"
    exit 1
fi

# 备份当前版本
echo -e "${BLUE}💾 备份当前版本...${NC}"
BACKUP_DIR="../gaopeng-demo-backup-$(date +%Y%m%d_%H%M%S)"
cp -r . "$BACKUP_DIR" 2>/dev/null || {
    echo -e "${YELLOW}⚠️ 无法创建备份，继续更新...${NC}"
}

# 停止当前服务
echo -e "${BLUE}⏹️ 停止当前服务...${NC}"
pm2 stop gaopeng-demo 2>/dev/null || echo -e "${YELLOW}⚠️ PM2服务未运行${NC}"

# 拉取最新代码
echo -e "${BLUE}📡 拉取最新代码...${NC}"
git fetch origin
git reset --hard origin/main

# 安装依赖
echo -e "${BLUE}📦 安装/更新依赖...${NC}"
npm ci

# 构建项目
echo -e "${BLUE}🔧 构建项目...${NC}"
npm run build

# 重启服务
echo -e "${BLUE}🔄 重启服务...${NC}"
if pm2 list | grep -q "gaopeng-demo"; then
    pm2 restart gaopeng-demo
else
    # 如果PM2服务不存在，启动新服务
    pm2 start .next/standalone/server.js --name gaopeng-demo
    pm2 save
fi

# 重新加载Nginx
echo -e "${BLUE}🌐 重新加载Nginx...${NC}"
sudo systemctl reload nginx 2>/dev/null || echo -e "${YELLOW}⚠️ Nginx重新加载失败，请手动检查${NC}"

# 运行健康检查
echo -e "${BLUE}🏥 运行健康检查...${NC}"
sleep 5

# 检查服务状态
if pm2 list | grep -q "gaopeng-demo.*online"; then
    echo -e "${GREEN}✅ PM2服务运行正常${NC}"
else
    echo -e "${RED}❌ PM2服务启动失败${NC}"
    echo -e "${YELLOW}正在尝试重新启动...${NC}"
    pm2 delete gaopeng-demo 2>/dev/null || true
    pm2 start .next/standalone/server.js --name gaopeng-demo
fi

# 检查网站访问
echo -e "${BLUE}🌐 检查网站访问...${NC}"
if curl -s -I "http://localhost:3000" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ 本地服务访问正常${NC}"
else
    echo -e "${RED}❌ 本地服务访问异常${NC}"
fi

# 显示服务状态
echo -e "${BLUE}📊 当前服务状态:${NC}"
pm2 list | grep gaopeng-demo || echo "未找到gaopeng-demo服务"

echo ""
echo -e "${GREEN}🎉 服务器更新完成！${NC}"
echo -e "${BLUE}📋 后续步骤:${NC}"
echo -e "1. 访问 https://www.gaopeng.site 检查网站"
echo -e "2. 如有问题，运行: ./monitor.sh check"
echo -e "3. 查看日志: pm2 logs gaopeng-demo"
echo ""
echo -e "${GREEN}✨ 更新成功！${NC}"
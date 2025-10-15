#!/bin/bash

# 服务监控和维护脚本
# 用于监控 www.gaopeng.site 的健康状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
DOMAIN="www.gaopeng.site"
APP_NAME="gaopeng-demo"
LOG_DIR="/var/log/monitoring"
ALERT_EMAIL="admin@gaopeng.site"  # 请修改为您的邮箱

# 创建日志目录
sudo mkdir -p $LOG_DIR

# 记录日志函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | sudo tee -a "$LOG_DIR/monitor.log"
}

# 检查服务状态
check_service_status() {
    echo -e "${BLUE}🔍 检查服务状态...${NC}"

    # 检查 PM2 进程
    if pm2 list | grep -q "$APP_NAME.*online"; then
        echo -e "${GREEN}✅ PM2 进程正常运行${NC}"
        log_message "INFO" "PM2 process is running normally"
    else
        echo -e "${RED}❌ PM2 进程异常${NC}"
        log_message "ERROR" "PM2 process is not running"
        return 1
    fi

    # 检查 Nginx 状态
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ Nginx 服务正常${NC}"
        log_message "INFO" "Nginx service is active"
    else
        echo -e "${RED}❌ Nginx 服务异常${NC}"
        log_message "ERROR" "Nginx service is not active"
        return 1
    fi
}

# 检查网站可访问性
check_website_accessibility() {
    echo -e "${BLUE}🌐 检查网站可访问性...${NC}"

    # 检查 HTTP 重定向
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" || echo "000")
    if [[ "$HTTP_STATUS" == "301" ]] || [[ "$HTTP_STATUS" == "302" ]]; then
        echo -e "${GREEN}✅ HTTP 重定向正常 ($HTTP_STATUS)${NC}"
        log_message "INFO" "HTTP redirect working: $HTTP_STATUS"
    else
        echo -e "${RED}❌ HTTP 重定向异常 ($HTTP_STATUS)${NC}"
        log_message "ERROR" "HTTP redirect failed: $HTTP_STATUS"
    fi

    # 检查 HTTPS 访问
    HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" || echo "000")
    if [[ "$HTTPS_STATUS" == "200" ]]; then
        echo -e "${GREEN}✅ HTTPS 访问正常${NC}"
        log_message "INFO" "HTTPS access working"
    else
        echo -e "${RED}❌ HTTPS 访问异常 ($HTTPS_STATUS)${NC}"
        log_message "ERROR" "HTTPS access failed: $HTTPS_STATUS"
        return 1
    fi

    # 检查响应时间
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "https://$DOMAIN" || echo "999")
    if (( $(echo "$RESPONSE_TIME < 5.0" | bc -l) )); then
        echo -e "${GREEN}✅ 响应时间正常 (${RESPONSE_TIME}s)${NC}"
        log_message "INFO" "Response time normal: ${RESPONSE_TIME}s"
    else
        echo -e "${YELLOW}⚠️ 响应时间较慢 (${RESPONSE_TIME}s)${NC}"
        log_message "WARNING" "Slow response time: ${RESPONSE_TIME}s"
    fi
}

# 检查 SSL 证书
check_ssl_certificate() {
    echo -e "${BLUE}🔐 检查 SSL 证书...${NC}"

    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        EXPIRY=$(openssl x509 -noout -dates -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" | grep "notAfter" | cut -d= -f2)
        EXPIRY_TIMESTAMP=$(date -d "$EXPIRY" +%s)
        CURRENT_TIMESTAMP=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

        if [[ $DAYS_LEFT -gt 30 ]]; then
            echo -e "${GREEN}✅ SSL 证书有效 (剩余 $DAYS_LEFT 天)${NC}"
            log_message "INFO" "SSL certificate valid: $DAYS_LEFT days left"
        elif [[ $DAYS_LEFT -gt 7 ]]; then
            echo -e "${YELLOW}⚠️ SSL 证书即将过期 (剩余 $DAYS_LEFT 天)${NC}"
            log_message "WARNING" "SSL certificate expiring soon: $DAYS_LEFT days left"
        else
            echo -e "${RED}❌ SSL 证书即将过期 (剩余 $DAYS_LEFT 天)${NC}"
            log_message "ERROR" "SSL certificate expiring: $DAYS_LEFT days left"
            return 1
        fi
    else
        echo -e "${RED}❌ 未找到 SSL 证书${NC}"
        log_message "ERROR" "SSL certificate not found"
        return 1
    fi
}

# 检查系统资源
check_system_resources() {
    echo -e "${BLUE}💻 检查系统资源...${NC}"

    # 检查磁盘使用率
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $DISK_USAGE -lt 80 ]]; then
        echo -e "${GREEN}✅ 磁盘使用率正常 ($DISK_USAGE%)${NC}"
        log_message "INFO" "Disk usage normal: $DISK_USAGE%"
    elif [[ $DISK_USAGE -lt 90 ]]; then
        echo -e "${YELLOW}⚠️ 磁盘使用率较高 ($DISK_USAGE%)${NC}"
        log_message "WARNING" "High disk usage: $DISK_USAGE%"
    else
        echo -e "${RED}❌ 磁盘使用率过高 ($DISK_USAGE%)${NC}"
        log_message "ERROR" "Critical disk usage: $DISK_USAGE%"
    fi

    # 检查内存使用率
    MEMORY_USAGE=$(free | awk 'NR==2{printf \"%.0f\", $3*100/$2}')
    if [[ $MEMORY_USAGE -lt 80 ]]; then
        echo -e "${GREEN}✅ 内存使用率正常 ($MEMORY_USAGE%)${NC}"
        log_message "INFO" "Memory usage normal: $MEMORY_USAGE%"
    elif [[ $MEMORY_USAGE -lt 90 ]]; then
        echo -e "${YELLOW}⚠️ 内存使用率较高 ($MEMORY_USAGE%)${NC}"
        log_message "WARNING" "High memory usage: $MEMORY_USAGE%"
    else
        echo -e "${RED}❌ 内存使用率过高 ($MEMORY_USAGE%)${NC}"
        log_message "ERROR" "Critical memory usage: $MEMORY_USAGE%"
    fi

    # 检查 CPU 负载
    LOAD_AVERAGE=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
    CPU_CORES=$(nproc)
    LOAD_PERCENTAGE=$(echo "scale=0; ($LOAD_AVERAGE / $CPU_CORES) * 100" | bc)

    if [[ $LOAD_PERCENTAGE -lt 70 ]]; then
        echo -e "${GREEN}✅ CPU 负载正常 ($LOAD_AVERAGE)${NC}"
        log_message "INFO" "CPU load normal: $LOAD_AVERAGE"
    elif [[ $LOAD_PERCENTAGE -lt 90 ]]; then
        echo -e "${YELLOW}⚠️ CPU 负载较高 ($LOAD_AVERAGE)${NC}"
        log_message "WARNING" "High CPU load: $LOAD_AVERAGE"
    else
        echo -e "${RED}❌ CPU 负载过高 ($LOAD_AVERAGE)${NC}"
        log_message "ERROR" "Critical CPU load: $LOAD_AVERAGE"
    fi
}

# 检查应用日志
check_application_logs() {
    echo -e "${BLUE}📝 检查应用日志...${NC}"

    # 检查 PM2 错误日志
    ERROR_COUNT=$(sudo tail -n 100 "/var/log/pm2/$APP_NAME-error.log" 2>/dev/null | grep -c "ERROR\|Error\|error" || echo "0")
    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${GREEN}✅ 近期无错误日志${NC}"
        log_message "INFO" "No recent errors in application logs"
    else
        echo -e "${YELLOW}⚠️ 发现 $ERROR_COUNT 个错误日志${NC}"
        log_message "WARNING" "Found $ERROR_COUNT errors in application logs"
    fi

    # 检查 Nginx 错误日志
    NGINX_ERRORS=$(sudo tail -n 100 /var/log/nginx/error.log 2>/dev/null | grep -c "error\|ERROR" || echo "0")
    if [[ $NGINX_ERRORS -eq 0 ]]; then
        echo -e "${GREEN}✅ Nginx 无错误日志${NC}"
        log_message "INFO" "No errors in Nginx logs"
    else
        echo -e "${YELLOW}⚠️ Nginx 发现 $NGINX_ERRORS 个错误${NC}"
        log_message "WARNING" "Found $NGINX_ERRORS errors in Nginx logs"
    fi
}

# 自动修复尝试
auto_fix_attempt() {
    echo -e "${BLUE}🔧 尝试自动修复...${NC}"

    # 重启 PM2 应用（如果进程异常）
    if ! pm2 list | grep -q "$APP_NAME.*online"; then
        echo -e "${YELLOW}🔄 重启 PM2 应用...${NC}"
        pm2 restart $APP_NAME
        sleep 5
        log_message "INFO" "Attempted PM2 restart"
    fi

    # 重新加载 Nginx（如果服务异常）
    if ! systemctl is-active --quiet nginx; then
        echo -e "${YELLOW}🔄 重启 Nginx 服务...${NC}"
        sudo systemctl restart nginx
        sleep 3
        log_message "INFO" "Attempted Nginx restart"
    fi
}

# 生成状态报告
generate_status_report() {
    local report_file="$LOG_DIR/status_report_$(date +%Y%m%d_%H%M%S).txt"

    echo "=== www.gaopeng.site 状态报告 ===" > "$report_file"
    echo "生成时间: $(date)" >> "$report_file"
    echo "" >> "$report_file"

    echo "--- 服务状态 ---" >> "$report_file"
    pm2 list >> "$report_file" 2>&1
    echo "" >> "$report_file"

    echo "--- 系统资源 ---" >> "$report_file"
    echo "磁盘使用: $(df -h /)" >> "$report_file"
    echo "内存使用: $(free -h)" >> "$report_file"
    echo "CPU负载: $(uptime)" >> "$report_file"
    echo "" >> "$report_file"

    echo "--- 最近错误日志 ---" >> "$report_file"
    sudo tail -n 20 "/var/log/pm2/$APP_NAME-error.log" >> "$report_file" 2>/dev/null || echo "无错误日志" >> "$report_file"

    echo -e "${GREEN}✅ 状态报告已生成: $report_file${NC}"
}

# 清理旧日志
cleanup_old_logs() {
    echo -e "${BLUE}🧹 清理旧日志...${NC}"

    # 清理监控日志（保留30天）
    find "$LOG_DIR" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true

    # 清理状态报告（保留7天）
    find "$LOG_DIR" -name "status_report_*.txt" -type f -mtime +7 -delete 2>/dev/null || true

    # 压缩 PM2 日志
    sudo find /var/log/pm2/ -name "*.log" -size +10M -exec gzip {} \; 2>/dev/null || true

    log_message "INFO" "Log cleanup completed"
    echo -e "${GREEN}✅ 日志清理完成${NC}"
}

# 主检查函数
main_check() {
    local exit_code=0

    echo -e "${BLUE}🚀 开始健康检查 - $(date)${NC}"
    log_message "INFO" "Health check started"

    check_service_status || exit_code=1
    check_website_accessibility || exit_code=1
    check_ssl_certificate || exit_code=1
    check_system_resources
    check_application_logs

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}❌ 发现问题，尝试自动修复...${NC}"
        auto_fix_attempt

        # 再次检查
        sleep 10
        if check_service_status && check_website_accessibility; then
            echo -e "${GREEN}✅ 自动修复成功${NC}"
            log_message "INFO" "Auto-fix successful"
            exit_code=0
        else
            echo -e "${RED}❌ 自动修复失败，需要人工干预${NC}"
            log_message "ERROR" "Auto-fix failed, manual intervention required"
        fi
    fi

    generate_status_report
    cleanup_old_logs

    log_message "INFO" "Health check completed with exit code: $exit_code"
    return $exit_code
}

# 显示使用帮助
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  check       执行完整健康检查（默认）"
    echo "  service     仅检查服务状态"
    echo "  website     仅检查网站可访问性"
    echo "  ssl         仅检查SSL证书"
    echo "  resources   仅检查系统资源"
    echo "  logs        仅检查应用日志"
    echo "  report      生成状态报告"
    echo "  cleanup     清理旧日志"
    echo "  help        显示此帮助信息"
}

# 参数处理
case "${1:-check}" in
    "check")
        main_check
        ;;
    "service")
        check_service_status
        ;;
    "website")
        check_website_accessibility
        ;;
    "ssl")
        check_ssl_certificate
        ;;
    "resources")
        check_system_resources
        ;;
    "logs")
        check_application_logs
        ;;
    "report")
        generate_status_report
        ;;
    "cleanup")
        cleanup_old_logs
        ;;
    "help")
        show_usage
        ;;
    *)
        echo "未知选项: $1"
        show_usage
        exit 1
        ;;
esac
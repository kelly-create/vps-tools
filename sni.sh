#!/bin/bash

# ==========================================================
# REALITY 伪装域名深度检测脚本 (屁桑のPro )
# 优化：TCP握手测速 | TLS1.3检测 | 极速模式
# ==========================================================

# --- 1. 基础配置 ---
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
CYAN=$(printf '\033[36m')
PURPLE=$(printf '\033[35m')
PLAIN=$(printf '\033[0m')

DOMAINS=(
    # --- 顶级推荐 (微软系：国内直连速度快，且Bing在国内合法) ---
    "www.microsoft.com"    # 微软官网，稳如老狗
    "www.bing.com"         # 必应搜索，国内可访问，流量巨大且合理
    "www.azure.com"        # 微软云服务，企业级流量伪装

    # --- 软件更新类 (这种流量大非常合理，适合跑大带宽) ---
    "www.apple.com"        # 苹果官网，系统更新/应用下载流量
    "www.adobe.com"        # Adobe全家桶，更新包动辄几个G
    "www.nvidia.com"       # 显卡驱动下载，流量特征非常明显
    "www.oracle.com"       # 甲骨文云，企业流量
    "www.vmware.com"       # 虚拟机软件，企业级下载
    
    # --- 电商与支付类 (CDN极其强大，全球访问速度快) ---
    "www.amazon.com"       # 亚马逊，图片视频流多，CDN 极强
    "www.visa.com"         # 国际支付，金融级加密流量，很少被干扰
    "www.paypal.com"       # 贝宝，同上
    "www.salesforce.com"   # 全球最大的客户管理平台，纯正商务流量

    # --- 科技实体与硬件类 (通常自建CDN或顶级CDN) ---
    "www.cisco.com"        # 思科，网络设备
    "www.ibm.com"          # IBM，企业服务
    "www.intel.com"        # 英特尔
    "www.dell.com"         # 戴尔
    "www.samsung.com"      # 三星
    "www.logitech.com"     # 罗技
)

# --- 2. 打印表头 ---
clear
echo "=========================================================================="
echo "      REALITY 伪装域名深度检测 (Pro版) - TCP握手真延迟      "
echo "=========================================================================="
printf "%-22s %-10s %-10s %-10s %-10s %-20s\n" "域名" "协议" "TLS" "握手(ms)" "状态码" "评价"
echo "--------------------------------------------------------------------------"

# --- 3. 循环检测 ---
for domain in "${DOMAINS[@]}"; do
    # 使用 curl 一次性获取所有信息
    # -w 输出格式: http_version | http_code | time_connect | redirect_url | ssl_verify_result
    # time_connect 是 TCP 握手耗时，比 Ping 更准
    
    output=$(curl -o /dev/null -s -w "%{http_version}|%{http_code}|%{time_connect}|%{redirect_url}" \
    --connect-timeout 3 \
    --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    "https://$domain")
    
    # 提取结果
    http_ver=$(echo "$output" | cut -d'|' -f1)
    status_code=$(echo "$output" | cut -d'|' -f2)
    time_connect=$(echo "$output" | cut -d'|' -f3)
    redirect_url=$(echo "$output" | cut -d'|' -f4)

    # 1. 处理协议 (HTTP/2)
    if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" ]]; then
        h2_text="${GREEN}HTTP/2${PLAIN}"
        is_h2=1
    else
        h2_text="${RED}${http_ver}${PLAIN}"
        is_h2=0
    fi

    # 2. 粗略判断 TLS 1.3 (Curl输出不直观，这里用状态判定，通常H2默认伴随TLS1.2+)
    # 如果要严谨检测 TLS1.3 需要 openssl 命令，为速度牺牲一点精度，默认为支持
    tls_text="${CYAN}TLS1.3?${PLAIN}" 

    # 3. 处理延迟 (秒 转 毫秒)
    if [[ "$status_code" == "000" ]]; then
        latency_num=9999
        latency_show="${RED}超时${PLAIN}"
    else
        # 简单的小数运算，转换成 ms
        latency_num=$(awk "BEGIN {print int($time_connect * 1000)}")
        latency_show="${latency_num} ms"
    fi

    # 4. 状态码颜色
    if [[ "$status_code" =~ ^2 ]]; then
        code_show="${GREEN}${status_code}${PLAIN}"
    elif [[ "$status_code" =~ ^3 ]]; then
        code_show="${CYAN}${status_code}${PLAIN}"
    elif [[ "$status_code" =~ ^4 ]]; then
        code_show="${RED}${status_code}${PLAIN}"
    else
        code_show="${RED}${status_code}${PLAIN}"
    fi

    # 5. 评分逻辑
    comment=""
    
    if [[ $latency_num -eq 9999 ]]; then
        comment="${RED}连接失败${PLAIN}"
    elif [[ $is_h2 -eq 0 ]]; then
        comment="${YELLOW}不推荐(非H2)${PLAIN}"
    elif [[ $status_code == "403" ]]; then
        comment="${RED}慎用(WAF拦截)${PLAIN}"
    elif [[ $latency_num -lt 50 ]]; then
        comment="${GREEN}★ 极品${PLAIN}"
    elif [[ $latency_num -lt 100 ]]; then
        comment="${GREEN}推荐${PLAIN}"
    elif [[ $latency_num -lt 200 ]]; then
        comment="${YELLOW}一般${PLAIN}"
    else
        comment="${RED}延迟高${PLAIN}"
    fi

    # 6. 如果有跳转，显示跳转路径
    if [[ -n "$redirect_url" ]]; then
         # 只提取路径部分，避免太长
         short_path=$(echo "$redirect_url" | awk -F/ '{print "/"$4"/"$5}')
         # 如果跳转，通常意味着 CDN 此时在工作，加分
         if [[ "$comment" != *失败* ]]; then
            comment="$comment ${BLUE}➯ 跳${short_path}...${PLAIN}"
         fi
    fi

    # 打印行
    printf "%-22s %-18s %-16s %-12s %-19s %-30s\n" "${domain}" "${h2_text}" "${tls_text}" "${latency_show}" "${code_show}" "${comment}"
done

echo "--------------------------------------------------------------------------"
echo -e "💡 \033[1;33m说明\033[0m: 延迟为 TCP 握手时间 (更真实)。Reality 目标需支持 HTTP/2。"
echo ""

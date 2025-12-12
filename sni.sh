#!/bin/bash

# ==========================================================
# REALITY 伪装域名深度检测 (最终完美版)
# 特性：随机User-Agent | 智能排序 | 毫秒级精度 | 进度条
# ==========================================================

# --- 1. 基础配置 ---
# 颜色定义
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
CYAN=$(printf '\033[36m')
PLAIN=$(printf '\033[0m')

# 域名列表 (微软系 + 苹果系 + 大厂云)
DOMAINS=(
    "www.microsoft.com"
    "www.bing.com"
    "www.azure.com"
    "www.apple.com"
    "www.adobe.com"
    "www.nvidia.com"
    "www.oracle.com"
    "www.vmware.com"
    "www.amazon.com"
    "www.visa.com"
    "www.paypal.com"
    "www.salesforce.com"
    "www.cisco.com"
    "www.ibm.com"
    "www.intel.com"
    "www.dell.com"
    "www.samsung.com"
    "www.logitech.com"
)

# --- 定义随机 User-Agent 池 (包含 Chrome/Edge/Firefox 的 Win/Mac 最新版) ---
UA_LIST=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:125.0) Gecko/20100101 Firefox/125.0"
)

# 存储结果
RESULTS=()
TOTAL=${#DOMAINS[@]}
CURRENT=0

# --- 2. 开始检测 ---
clear
echo "========================================================================"
echo "      REALITY 伪装域名深度检测 (随机UA抗封锁版)      "
echo "========================================================================"
echo -e "${YELLOW}正在扫描 ${TOTAL} 个域名... (模拟真实浏览器访问)${PLAIN}"

for domain in "${DOMAINS[@]}"; do
    let CURRENT++
    
    # --- 核心优化：随机抽取 User-Agent ---
    # $RANDOM 是 Bash 内置随机数，对数组长度取模得到随机索引
    current_ua="${UA_LIST[$RANDOM % ${#UA_LIST[@]}]}"

    # 打印进度条
    printf "\r[%-20s] %d/%d 检测: %s ..." $(head -c $(($CURRENT*20/$TOTAL)) < /dev/zero | tr '\0' '#') $CURRENT $TOTAL "$domain"

    # curl 请求 (使用 -A 传入随机 UA)
    output=$(curl -o /dev/null -s -w "%{http_version}|%{http_code}|%{time_connect}|%{redirect_url}" \
    --connect-timeout 3 \
    -A "$current_ua" \
    "https://$domain")
    
    # 提取结果
    http_ver=$(echo "$output" | cut -d'|' -f1)
    status_code=$(echo "$output" | cut -d'|' -f2)
    time_connect=$(echo "$output" | cut -d'|' -f3)
    redirect_url=$(echo "$output" | cut -d'|' -f4)

    # --- 评分与排序逻辑 (Rank算法) ---
    if [[ "$status_code" == "000" ]]; then
        rank=90
        latency_float=9999
        latency_display="超时"
    else
        # 延迟换算 ms
        latency_float=$(awk "BEGIN {printf \"%.3f\", $time_connect * 1000}")
        latency_display="${latency_float} ms"
        
        # 协议判断
        is_h2=0
        if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" ]]; then is_h2=1; fi
        
        if [[ $is_h2 -eq 0 ]]; then
            rank=30 # 非H2
        elif [[ "$status_code" == "403" ]]; then
            rank=20 # 403
        else
            rank=10 # 完美 (200/30x)
        fi
    fi

    # 存入数组用于排序
    RESULTS+=("$rank|$latency_float|$domain|$http_ver|$status_code|$latency_display|$redirect_url")
done

printf "\r\033[K" # 清除进度条

# --- 3. 排序输出 ---
printf "%-22s %-12s %-15s %-10s %-20s\n" "域名" "协议" "握手(ms)" "状态码" "评价"
echo "------------------------------------------------------------------------"

# 排序: Rank升序 -> 延迟升序
IFS=$'\n' sorted_results=($(sort -t'|' -k1,1n -k2,2n <<<"${RESULTS[*]}"))
unset IFS

for line in "${sorted_results[@]}"; do
    rank=$(echo "$line" | cut -d'|' -f1)
    domain=$(echo "$line" | cut -d'|' -f3)
    http_ver=$(echo "$line" | cut -d'|' -f4)
    status_code=$(echo "$line" | cut -d'|' -f5)
    latency_display=$(echo "$line" | cut -d'|' -f6)
    redirect_url=$(echo "$line" | cut -d'|' -f7)
    latency_val=$(echo "$line" | cut -d'|' -f2 | awk '{print int($1)}')

    # 样式处理
    if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" ]]; then
        h2_text="${GREEN}HTTP/2${PLAIN}"
    else
        h2_text="${RED}${http_ver}${PLAIN}"
    fi

    if [[ "$status_code" =~ ^2 ]]; then code_show="${GREEN}${status_code}${PLAIN}"
    elif [[ "$status_code" =~ ^3 ]]; then code_show="${CYAN}${status_code}${PLAIN}"
    else code_show="${RED}${status_code}${PLAIN}"; fi

    # 评价文案
    comment=""
    if [[ $rank -eq 90 ]]; then
        comment="${RED}连接失败${PLAIN}"
        code_show="${RED}Err${PLAIN}"
    elif [[ $rank -eq 30 ]]; then
        comment="${YELLOW}不推荐(非H2)${PLAIN}"
    elif [[ $rank -eq 20 ]]; then
        comment="${RED}慎用(WAF拦截)${PLAIN}"
    else
        if [[ $latency_val -lt 20 ]]; then comment="${GREEN}★ 极品 (同城)${PLAIN}"
        elif [[ $latency_val -lt 50 ]]; then comment="${GREEN}☆ 优秀 (近邻)${PLAIN}"
        elif [[ $latency_val -lt 100 ]]; then comment="${BLUE}推荐 (地区)${PLAIN}"
        else comment="${YELLOW}一般${PLAIN}"; fi
    fi

    # 跳转显示
    if [[ -n "$redirect_url" && $rank -lt 90 ]]; then
         short_path=$(echo "$redirect_url" | awk -F/ '{print "/"$4"/"$5}')
         comment="$comment ${CYAN}➯ 跳${short_path}...${PLAIN}"
    fi

    printf "%-22s %-20s %-18s %-19s %-30s\n" "${domain}" "${h2_text}" "${latency_display}" "${code_show}" "${comment}"
done

echo "------------------------------------------------------------------------"
echo -e "${YELLOW}【📊 结果解读】${PLAIN}"
echo -e "1. 脚本已使用 \033[1;36m随机 User-Agent\033[0m 模拟 Chrome/Edge/Firefox，避免被 WAF 误杀。"
echo -e "2. \033[1;32m排在第一位\033[0m 的域名就是目前网络环境下最快、最稳的选择。"
echo ""

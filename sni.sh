#!/bin/bash

# ==========================================================
# REALITY 伪装域名深度检测 (智能排序版)
# 特性：自动按质量排序 | 毫秒级精度 | 进度提示
# ==========================================================

# --- 1. 基础配置 ---
# 颜色定义
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
CYAN=$(printf '\033[36m')
PLAIN=$(printf '\033[0m')
BOLD=$(printf '\033[1m')

# 域名列表 (中国友好 + 大流量特征)
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

# 存储结果的数组
RESULTS=()
TOTAL=${#DOMAINS[@]}
CURRENT=0

# --- 2. 开始检测 ---
clear
echo "========================================================================"
echo "      REALITY 伪装域名深度检测 (智能排序版)      "
echo "========================================================================"
echo -e "${YELLOW}正在扫描 ${TOTAL} 个域名，请稍候... (结果将自动按质量排序)${PLAIN}"

for domain in "${DOMAINS[@]}"; do
    let CURRENT++
    # 打印进度条 (覆盖同一行)
    printf "\r[%-20s] %d/%d 检测中: %s ..." $(head -c $(($CURRENT*20/$TOTAL)) < /dev/zero | tr '\0' '#') $CURRENT $TOTAL "$domain"

    # curl 抓取核心数据
    output=$(curl -o /dev/null -s -w "%{http_version}|%{http_code}|%{time_connect}|%{redirect_url}" \
    --connect-timeout 3 \
    --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    "https://$domain")
    
    # 提取结果
    http_ver=$(echo "$output" | cut -d'|' -f1)
    status_code=$(echo "$output" | cut -d'|' -f2)
    time_connect=$(echo "$output" | cut -d'|' -f3)
    redirect_url=$(echo "$output" | cut -d'|' -f4)

    # 计算排序权重 (Rank) 和 显示用延迟
    # Rank 规则: 
    # 10 = 完美 (H2 + 200/30x)
    # 20 = 警告 (H2 + 403)
    # 30 = 差评 (非H2)
    # 90 = 失败 (超时)
    
    if [[ "$status_code" == "000" ]]; then
        rank=90
        latency_float=9999
        latency_display="超时"
    else
        # 延迟处理
        latency_float=$(awk "BEGIN {printf \"%.3f\", $time_connect * 1000}")
        latency_display="${latency_float} ms"
        
        # 协议与状态判定
        is_h2=0
        if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" ]]; then is_h2=1; fi
        
        if [[ $is_h2 -eq 0 ]]; then
            rank=30 # 非H2排后面
        elif [[ "$status_code" == "403" ]]; then
            rank=20 # 403排中间
        else
            rank=10 # 正常排最前
        fi
    fi

    # 将原始数据存入数组，用 '|' 分隔，方便后续排序
    # 格式: Rank|LatencyFloat|Domain|HttpVer|StatusCode|LatencyDisplay|RedirectUrl
    RESULTS+=("$rank|$latency_float|$domain|$http_ver|$status_code|$latency_display|$redirect_url")
done

# 清除进度行
printf "\r\033[K" 

# --- 3. 排序与输出 ---
# 打印表头
printf "%-22s %-12s %-15s %-10s %-20s\n" "域名" "协议" "握手(ms)" "状态码" "评价"
echo "------------------------------------------------------------------------"

# 排序逻辑：先按 Rank(升序) -> 再按 Latency(升序)
# IFS=$'\n' 用于处理换行
IFS=$'\n' sorted_results=($(sort -t'|' -k1,1n -k2,2n <<<"${RESULTS[*]}"))
unset IFS

# 循环输出排序后的结果
for line in "${sorted_results[@]}"; do
    # 解析行数据
    rank=$(echo "$line" | cut -d'|' -f1)
    domain=$(echo "$line" | cut -d'|' -f3)
    http_ver=$(echo "$line" | cut -d'|' -f4)
    status_code=$(echo "$line" | cut -d'|' -f5)
    latency_display=$(echo "$line" | cut -d'|' -f6)
    redirect_url=$(echo "$line" | cut -d'|' -f7)
    latency_val=$(echo "$line" | cut -d'|' -f2 | awk '{print int($1)}')

    # --- 格式化显示逻辑 (与之前相同) ---
    
    # 协议颜色
    if [[ "$http_ver" == "2" || "$http_ver" == "HTTP/2" ]]; then
        h2_text="${GREEN}HTTP/2${PLAIN}"
    else
        h2_text="${RED}${http_ver}${PLAIN}"
    fi

    # 状态码颜色
    if [[ "$status_code" =~ ^2 ]]; then code_show="${GREEN}${status_code}${PLAIN}"
    elif [[ "$status_code" =~ ^3 ]]; then code_show="${CYAN}${status_code}${PLAIN}"
    else code_show="${RED}${status_code}${PLAIN}"; fi

    # 评价生成
    comment=""
    if [[ $rank -eq 90 ]]; then
        comment="${RED}连接失败${PLAIN}"
        latency_display="${RED}超时${PLAIN}"
        code_show="${RED}Err${PLAIN}"
    elif [[ $rank -eq 30 ]]; then
        comment="${YELLOW}不推荐(非H2)${PLAIN}"
    elif [[ $rank -eq 20 ]]; then
        comment="${RED}慎用(WAF拦截)${PLAIN}"
    else
        # 正常的 Rank 10，根据延迟细分
        if [[ $latency_val -lt 20 ]]; then comment="${GREEN}★ 极品 (同城)${PLAIN}"
        elif [[ $latency_val -lt 50 ]]; then comment="${GREEN}☆ 优秀 (近邻)${PLAIN}"
        elif [[ $latency_val -lt 100 ]]; then comment="${BLUE}推荐 (地区)${PLAIN}"
        else comment="${YELLOW}一般${PLAIN}"; fi
    fi

    # 跳转路径
    if [[ -n "$redirect_url" && $rank -lt 90 ]]; then
         short_path=$(echo "$redirect_url" | awk -F/ '{print "/"$4"/"$5}')
         comment="$comment ${CYAN}➯ 跳${short_path}...${PLAIN}"
    fi

    # 最终打印
    printf "%-22s %-20s %-18s %-19s %-30s\n" "${domain}" "${h2_text}" "${latency_display}" "${code_show}" "${comment}"
done

echo "------------------------------------------------------------------------"
# --- 4. 详细评级说明 ---
echo ""
echo -e "${YELLOW}【📊 评级标准与选择建议】${PLAIN}"
echo "------------------------------------------------------------------------"
echo -e "1. ${GREEN}★ 极品 (<20ms)${PLAIN} : 你的VPS和该网站在同一个城市或机房。速度最快，偷跑流量最稳。"
echo -e "2. ${GREEN}☆ 优秀 (<50ms)${PLAIN} : 同国家或邻近地区（如美西到美东），非常理想的选择。"
echo -e "3. ${BLUE}推荐 (<100ms)${PLAIN}  : 正常的洲内延迟，完全可用。"
echo -e "4. ${RED}慎用 (403/404)${PLAIN}  : 403代表对方防火墙拦截了你的IP；404代表页面不存在(不如200真实)。"
echo -e "5. ${YELLOW}非H2${PLAIN}            : 目标不支持 HTTP/2 (如 Visa)，不符合 Reality 最佳实践，易被识别。"
echo "------------------------------------------------------------------------"
echo -e "💡 提示：列表已自动按 [可用性 > 协议 > 延迟] 排序，\033[1;32m请直接选用第一行的域名。\033[0m"
echo ""

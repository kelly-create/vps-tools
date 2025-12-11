#!/bin/bash

# ==========================================================
# REALITY 伪装域名深度检测脚本 (V3.0 完美版)
# ==========================================================

# --- 1. 基础配置 ---
# 定义颜色
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[36m')
CYAN=$(printf '\033[36m')
PLAIN=$(printf '\033[0m')

# 定义域名列表
DOMAINS=(
    "www.nvidia.com"
    "www.apple.com"
    "www.microsoft.com"
    "www.adobe.com"
    "www.aws.amazon.com"
    "www.samsung.com"
    "www.oracle.com"
    "www.dell.com"
    "www.cisco.com"
    "swdist.apple.com"
    "dl.google.com"
    "www.tesla.com"
)

# --- 2. 打印表头 ---
clear
echo "=========================================================="
echo "      REALITY 伪装域名深度检测 (最终完美版)      "
echo "=========================================================="
printf "%-20s %-12s %-10s %-10s %-20s\n" "域名" "协议" "延时" "状态码" "评价"
echo "----------------------------------------------------------"

# --- 3. 循环检测 ---
for domain in "${DOMAINS[@]}"; do
    # 抓取头信息 (超时设置为2秒，防止卡顿)
    header=$(curl -I -s --connect-timeout 2 "https://$domain")
    
    # 检测 H2
    if echo "$header" | grep -q "HTTP/2"; then
        h2_text="${GREEN}HTTP/2${PLAIN}"
        is_h2=1
    else
        h2_text="${RED}不支持${PLAIN}"
        is_h2=0
    fi

    # 获取状态码
    code=$(echo "$header" | grep -i "^HTTP" | head -n 1 | awk '{print $2}')
    
    # 简单的状态码颜色处理
    if [[ "$code" =~ ^2 ]]; then
        code_show="${GREEN}${code}${PLAIN}" # 2xx 绿色
    elif [[ "$code" =~ ^3 ]]; then
        code_show="${CYAN}${code}${PLAIN}"  # 3xx 蓝色
    elif [[ "$code" =~ ^4 ]]; then
        code_show="${RED}${code}${PLAIN}"   # 4xx 红色
    else
        code_show="${PLAIN}${code}${PLAIN}"
    fi

    # 获取跳转 (Location)
    loc=$(echo "$header" | grep -i "location:" | awk '{print $2}' | tr -d '\r')
    
    # 测延时
    ping_val=$(ping -c 3 -W 1 "$domain" | tail -1 | awk -F '/' '{print $5}')
    
    if [[ -z "$ping_val" ]]; then
        latency_show="超时"
        latency_num=9999
    else
        latency_show="${ping_val} ms"
        latency_num=${ping_val%.*} 
    fi

    # 评分逻辑
    if [[ $is_h2 -eq 0 ]]; then
        comment="${RED}不可用${PLAIN}"
    elif [[ $latency_num -eq 9999 ]]; then
        comment="${RED}无法连接${PLAIN}"
    elif [[ $code == "403" ]]; then
        comment="${RED}慎用(被盾)${PLAIN}"
    elif [[ $latency_num -lt 20 ]]; then
        comment="${GREEN}★ 极品${PLAIN}"
    elif [[ $latency_num -lt 60 ]]; then
        comment="${GREEN}推荐${PLAIN}"
    else
        comment="${YELLOW}一般${PLAIN}"
    fi

    # 追加地区标识
    if [[ -n "$loc" ]]; then
        short_path=$(echo "$loc" | sed 's/https:\/\/[^\/]*//')
        if [[ ${#short_path} -gt 1 ]]; then
             comment="$comment ${BLUE}-> $short_path${PLAIN}"
        fi
    fi

    printf "%-20s %-18s %-10s %-19s %-30s\n" "${domain}" "${h2_text}" "${latency_show}" "${code_show}" "${comment}"
done

echo "----------------------------------------------------------"

# --- 4. 状态码科普 ---
echo -e "\n${YELLOW}【👇 状态码(Status Code) 科普与选择建议】${PLAIN}"
echo "----------------------------------------------------------"
echo -e "${GREEN}[200 OK]${PLAIN}       ✅ ${GREEN}完美${PLAIN} | 服务器正常响应。最稳的选择 (如 apple, microsoft)。"
echo -e "${CYAN}[301/302/307]${PLAIN}  ✅ ${GREEN}推荐${PLAIN} | 临时跳转。通常是跳到对应国家的子页面 (如 nvidia 跳 ja-jp)。"
echo -e "                 说明 CDN 精准识别了你的 IP 地区，速度通常最快。"
echo -e "${RED}[403 Forbidden]${PLAIN} ❌ ${RED}警告${PLAIN} | 拒绝访问。可能有防火墙 (WAF)，容易断流，不建议使用。"
echo -e "${RED}[404 Not Found]${PLAIN} ⚠️ ${YELLOW}一般${PLAIN} | 找不到页面。虽然握手成功可以用，但伪装效果不如 200/30x 真实。"
echo "----------------------------------------------------------"
echo -e "🏆 最佳选择策略：优先选 ${GREEN}延时低${PLAIN} + (${GREEN}200${PLAIN} 或 ${CYAN}30x${PLAIN}) 的域名。"
echo ""
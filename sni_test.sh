#!/bin/bash

# ==========================================================
# REALITY 伪装域名深度检测脚本 (优化版)
# ==========================================================

# --- 1. 基础配置 ---
# 定义颜色 (兼容 Windows Git Bash/WSL)
if [ -t 1 ]; then
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    CYAN=$(printf '\033[36m')
    PLAIN=$(printf '\033[0m')
else
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" PLAIN=""
fi

# 定义默认域名列表
DEFAULT_DOMAINS=(
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

# 如果有命令行参数，则使用参数作为域名，否则使用默认列表
if [ $# -gt 0 ]; then
    DOMAINS=("$@")
else
    DOMAINS=("${DEFAULT_DOMAINS[@]}")
fi

# --- 2. 打印表头 ---
clear
echo "=========================================================="
echo "      REALITY 伪装域名深度检测 (优化版)      "
echo "=========================================================="
# 使用 tab 或固定宽度来尝试对齐
printf "%-25s %-12s %-10s %-10s %-20s\n" "域名" "协议" "延时" "状态码" "评价"
echo "----------------------------------------------------------"

# --- 3. 循环检测 ---
for domain in "${DOMAINS[@]}"; do
    # 移除可能的 http/https 前缀
    clean_domain=$(echo "$domain" | sed -E 's~^https?://~~')
    
    # 使用 curl 一次性获取所有信息
    # %{http_code}: 状态码
    # %{time_connect}: TCP 建连时间 (秒)
    # %{redirect_url}: 重定向地址
    # %{http_version}: 协议版本
    # -o /dev/null: 不输出网页内容
    # -s: 静默模式
    # -w: 自定义输出格式
    # --connect-timeout 3: 3秒连接超时
    
    result=$(curl -o /dev/null -s -w "%{http_code}|%{time_connect}|%{redirect_url}|%{http_version}" --connect-timeout 3 "https://$clean_domain")
    
    # 检查 curl 是否执行成功
    if [ $? -ne 0 ]; then
        printf "%-25s %-12s %-10s %-10s %-20s\n" "${clean_domain}" "${RED}Fail${PLAIN}" "-" "-" "${RED}连接失败${PLAIN}"
        continue
    fi

    # 解析结果
    code=$(echo "$result" | cut -d'|' -f1)
    time_connect=$(echo "$result" | cut -d'|' -f2)
    redirect_url=$(echo "$result" | cut -d'|' -f3)
    http_version=$(echo "$result" | cut -d'|' -f4)

    # 1. 处理协议 (H2 检测)
    if [[ "$http_version" == "2" ]]; then
        h2_text="${GREEN}HTTP/2${PLAIN}"
        is_h2=1
    else
        h2_text="${RED}${http_version}${PLAIN}"
        is_h2=0
    fi

    # 2. 处理延时 (秒转毫秒)
    # awk 处理浮点数运算，兼容性好
    latency_ms=$(awk -v t="$time_connect" 'BEGIN { printf "%.0f", t * 1000 }')
    
    if [[ "$latency_ms" -ge 0 ]]; then
        latency_show="${latency_ms} ms"
    else
        latency_show="超时"
        latency_ms=9999
    fi

    # 3. 处理状态码颜色
    if [[ "$code" =~ ^2 ]]; then
        code_show="${GREEN}${code}${PLAIN}"
    elif [[ "$code" =~ ^3 ]]; then
        code_show="${CYAN}${code}${PLAIN}"
    elif [[ "$code" =~ ^4 ]]; then
        code_show="${RED}${code}${PLAIN}"
    else
        code_show="${PLAIN}${code}${PLAIN}"
    fi

    # 4. 评分逻辑
    comment=""
    if [[ $is_h2 -eq 0 ]]; then
        comment="${RED}不可用(非H2)${PLAIN}"
    elif [[ $latency_ms -eq 9999 ]]; then
        comment="${RED}无法连接${PLAIN}"
    elif [[ $code == "403" ]]; then
        comment="${RED}慎用(被盾)${PLAIN}"
    elif [[ $latency_ms -lt 50 ]]; then # 适当放宽极品标准
        comment="${GREEN}★ 极品${PLAIN}"
    elif [[ $latency_ms -lt 150 ]]; then
        comment="${GREEN}推荐${PLAIN}"
    else
        comment="${YELLOW}一般${PLAIN}"
    fi

    # 5. 追加地区/跳转标识
    if [[ -n "$redirect_url" ]]; then
        # 提取跳转目标的路径部分作为简短标识
        short_path=$(echo "$redirect_url" | sed -E 's~^https?://[^/]+~~')
        # 如果是根目录跳转，可能为空，显示域名后缀或许更有用，这里简单处理
        if [[ ${#short_path} -gt 1 ]]; then
             comment="$comment ${BLUE}-> $short_path${PLAIN}"
        else
             comment="$comment ${BLUE}-> 跳转${PLAIN}"
        fi
    fi

    # 输出结果
    printf "%-25s %-18s %-10s %-19s %-30s\n" "${clean_domain}" "${h2_text}" "${latency_show}" "${code_show}" "${comment}"
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

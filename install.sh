#!/usr/bin/env bash
# =======================================================
# 🧱 域名封锁管理脚本 v3
# 功能：
#   - 自动安装 iptables + iptables-persistent
#   - 添加单个域名封锁
#   - 显示带序号的列表并按序号删除
#   - 自动保存规则以便重启生效
# =======================================================

BLOCK_FILE="/etc/domain_block.list"

# 默认封锁域名
DEFAULT_DOMAINS=(
falundafa.org minghui.org epochtimes.com ntdtv.com voachinese.com appledaily.com nextdigital.com dalailama.com
nytimes.com bloomberg.com independent.co.uk freetibet.org citizenpowerforchina.org rfa.org bbc.com theinitium.com
tibet.net jw.org bannedbook.org dw.com storm.mg yam.com chinadigitaltimes.net ltn.com.tw mpweekly.com cup.com.hk
thenewslens.com inside.com.tw everylittled.com cool3c.com taketla.zaiko.io news.agentm.tw sportsv.net research.tnlmedia.com
ad2iction.com viad.com.tw tnlmedia.com becomingaces.com pincong.rocks flipboard.com soundofhope.org wenxuecity.com
aboluowang.com 2047.name shu.best shenyunperformingarts.org bbc.co.uk cirosantilli.com wsj.com rfi.fr chinapress.com.my
hancel.org miraheze.org zhuichaguoji.org fawanghuihui.org hopto.org amnesty.org hrw.org irmct.org zhengjian.org
wujieliulan.com dongtaiwang.com ultrasurf.us yibaochina.com roc-taiwan.org creaders.net upmedia.mg ydn.com.tw
udn.com theaustralian.com.au voacantonese.com voanews.com bitterwinter.org christianstudy.com learnfalungong.com
usembassy-china.org.cn master-li.qi-gong.me zhengwunet.org modernchinastudies.org ninecommentaries.com dafahao.com
shenyuncreations.com tgcchinese.org botanwang.com falungong.org freedomhouse.org abc.net.au
tracker.openbittorrent.com tracker.opentrackr.org tracker.torrent.eu.org tracker.publicbt.com tracker.coppersurfer.tk
speedtest.net www.speedtest.net fast.com speed.cloudflare.com fiber.google.com speedof.me speedsmart.net
testmy.net speedcheck.org internethealthtest.org openspeedtest.com bandwidthplace.com librespeed.org
)

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
  echo "❌ 请使用 root 权限运行。"
  exit 1
fi

# 安装依赖
echo "🧩 检查 iptables..."
if ! command -v iptables >/dev/null 2>&1; then
  apt update -y && apt install -y iptables iptables-persistent >/dev/null 2>&1
fi

# 初始化默认文件
[ ! -f "$BLOCK_FILE" ] && touch "$BLOCK_FILE"
if [ ! -s "$BLOCK_FILE" ]; then
  printf "%s\n" "${DEFAULT_DOMAINS[@]}" >"$BLOCK_FILE"
  echo "✅ 已写入默认封锁域名 (${#DEFAULT_DOMAINS[@]} 个)"
fi

# --- 功能函数 ---

# 根据域名解析 IP（不管通不通）
resolve_ip() {
  local domain="$1"
  ip=$(ping -c 1 -4 "$domain" 2>/dev/null | grep "PING" | sed -E 's/.*\(([^)]+)\).*/\1/')
  [ -z "$ip" ] && ip=$(dig +short "$domain" A 2>/dev/null | head -n1)
  echo "$ip"
}

# 添加封锁
add_block() {
  read -rp "输入要封锁的域名: " domain
  [ -z "$domain" ] && echo "⚠️ 不能为空。" && return
  echo "🔍 正在解析 $domain ..."
  ip=$(resolve_ip "$domain")
  if [ -z "$ip" ]; then
    echo "⚠️ 无法解析到 IP，仍记录域名。"
    grep -qxF "$domain" "$BLOCK_FILE" || echo "$domain" >>"$BLOCK_FILE"
    return
  fi
  iptables -C OUTPUT -d "$ip" -j DROP 2>/dev/null || iptables -I OUTPUT -d "$ip" -j DROP
  iptables -C FORWARD -d "$ip" -j DROP 2>/dev/null || iptables -I FORWARD -d "$ip" -j DROP
  grep -qxF "$domain" "$BLOCK_FILE" || echo "$domain" >>"$BLOCK_FILE"
  echo "🚫 已封锁：$domain ($ip)"
}

# 删除封锁（按序号）
delete_block() {
  if [ ! -s "$BLOCK_FILE" ]; then
    echo "（无封锁域名）"
    return
  fi
  echo "📋 当前封锁列表："
  nl -w2 -s'. ' "$BLOCK_FILE"
  echo
  read -rp "输入要删除的序号（多个用空格分隔）: " nums
  for n in $nums; do
    domain=$(sed -n "${n}p" "$BLOCK_FILE")
    [ -z "$domain" ] && continue
    echo "🧹 正在解除封锁：$domain ..."
    ip=$(resolve_ip "$domain")
    [ -n "$ip" ] && {
      iptables -D OUTPUT -d "$ip" -j DROP 2>/dev/null
      iptables -D FORWARD -d "$ip" -j DROP 2>/dev/null
    }
    sed -i "${n}d" "$BLOCK_FILE"
    echo "✅ 已删除：$domain"
  done
}

# 查看封锁列表
list_blocked() {
  echo "📋 当前封锁域名："
  if [ ! -s "$BLOCK_FILE" ]; then
    echo "（空）"
  else
    nl -w2 -s'. ' "$BLOCK_FILE"
  fi
}

# 一键重新封锁
apply_all() {
  echo "♻️ 正在重新封锁所有域名..."
  while read -r domain; do
    [ -n "$domain" ] && {
      ip=$(resolve_ip "$domain")
      if [ -n "$ip" ]; then
        iptables -C OUTPUT -d "$ip" -j DROP 2>/dev/null || iptables -I OUTPUT -d "$ip" -j DROP
        iptables -C FORWARD -d "$ip" -j DROP 2>/dev/null || iptables -I FORWARD -d "$ip" -j DROP
      fi
    }
  done <"$BLOCK_FILE"
  echo "✅ 已重新应用全部封锁。"
  netfilter-persistent save >/dev/null 2>&1 || iptables-save >/etc/iptables/rules.v4
  echo "💾 已保存持久规则。"
}

# --- 主菜单 ---
while true; do
  clear
  echo "=============================="
  echo "🧱 域名封锁管理系统"
  echo "=============================="
  echo "1. 添加域名封锁"
  echo "2. 删除域名封锁"
  echo "3. 查看当前封锁列表"
  echo "4. 一键重新封锁全部"
  echo "5. 保存规则并退出"
  echo "=============================="
  read -rp "请选择操作 [1-5]: " choice

  case $choice in
  1) add_block; read -rp "按回车返回菜单..." ;;
  2) delete_block; read -rp "按回车返回菜单..." ;;
  3) list_blocked; read -rp "按回车返回菜单..." ;;
  4) apply_all; read -rp "按回车返回菜单..." ;;
  5)
    echo "💾 正在保存规则..."
    netfilter-persistent save >/dev/null 2>&1 || iptables-save >/etc/iptables/rules.v4
    echo "✅ 已保存并退出。"
    exit 0
    ;;
  *) echo "❌ 无效选项"; sleep 1 ;;
  esac
done

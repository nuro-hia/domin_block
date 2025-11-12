#!/usr/bin/env bash
# =======================================================
# 🧱 域名封锁管理系统 v5（DNSmasq 一键封锁版）
# =======================================================

BLOCK_FILE="/etc/domain_block.list"
DNSMASQ_BLOCK="/etc/dnsmasq.d/blocklist.conf"

# 🌐 默认封锁域名列表（测速、新闻、代理类）
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

# === 函数 ===
require_root() {
  [ "$(id -u)" != "0" ] && { echo "❌ 请使用 root 用户运行"; exit 1; }
}

install_pkg() {
  local pkg=$1
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "📦 未检测到 $pkg，正在安装..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y -qq
    apt-get install -y -qq "$pkg"
    echo "✅ $pkg 安装完成"
  else
    echo "✅ 已检测到 $pkg"
  fi
}

init_files() {
  [ ! -f "$BLOCK_FILE" ] && touch "$BLOCK_FILE"
  if [ ! -s "$BLOCK_FILE" ]; then
    printf "%s\n" "${DEFAULT_DOMAINS[@]}" >"$BLOCK_FILE"
    echo "✅ 已加载默认域名 ${#DEFAULT_DOMAINS[@]} 个"
  fi
}

update_dnsmasq() {
  echo "💾 正在更新 dnsmasq 黑名单..."
  echo "# 自动生成：封锁域名列表" >"$DNSMASQ_BLOCK"
  while read -r domain; do
    [ -n "$domain" ] && echo "address=/$domain/0.0.0.0" >>"$DNSMASQ_BLOCK"
  done <"$BLOCK_FILE"

  # 确保系统 DNS 使用本地 dnsmasq
  echo "nameserver 127.0.0.1" >/etc/resolv.conf

  systemctl restart dnsmasq 2>/dev/null || service dnsmasq restart
  echo "✅ dnsmasq 黑名单已更新并生效"
}

add_block() {
  read -rp "输入要封锁的域名: " domain
  [ -z "$domain" ] && echo "⚠️ 不能为空" && return
  grep -qxF "$domain" "$BLOCK_FILE" || echo "$domain" >>"$BLOCK_FILE"
  echo "🚫 已加入封锁列表: $domain"
  update_dnsmasq
}

delete_block() {
  if [ ! -s "$BLOCK_FILE" ]; then
    echo "（无封锁域名）"; return
  fi
  echo "📋 当前封锁列表："
  nl -w2 -s'. ' "$BLOCK_FILE"
  read -rp "输入要删除的序号（可多个）: " nums
  for n in $nums; do
    sed -i "${n}d" "$BLOCK_FILE"
  done
  update_dnsmasq
  echo "✅ 已删除并更新 dnsmasq"
}

list_blocked() {
  echo "📋 当前封锁域名："
  if [ ! -s "$BLOCK_FILE" ]; then
    echo "（空）"
  else
    nl -w2 -s'. ' "$BLOCK_FILE"
  fi
}

apply_all() {
  update_dnsmasq
}

# === 主程序 ===
require_root
install_pkg dnsmasq
install_pkg iptables
install_pkg iptables-persistent
init_files
update_dnsmasq

while true; do
  clear
  echo "=============================="
  echo "🧱 域名封锁管理系统 (DNSmasq)"
  echo "=============================="
  echo "1. 添加域名封锁"
  echo "2. 删除域名封锁（按序号）"
  echo "3. 查看封锁列表"
  echo "4. 一键更新 dnsmasq 黑名单"
  echo "5. 保存并退出"
  echo "=============================="
  read -rp "请选择操作 [1-5]: " choice
  case $choice in
    1) add_block; read -rp "按回车返回菜单..." ;;
    2) delete_block; read -rp "按回车返回菜单..." ;;
    3) list_blocked; read -rp "按回车返回菜单..." ;;
    4) apply_all; read -rp "按回车返回菜单..." ;;
    5)
      echo "💾 保存并退出..."
      update_dnsmasq
      echo "✅ 已保存并退出。"
      exit 0
      ;;
    *) echo "❌ 无效选项"; sleep 1 ;;
  esac
done

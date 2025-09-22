#!/bin/sh
source /koolshare/scripts/base.sh
NEW_PATH=$(echo $PATH|tr ':' '\n'|sed '/opt/d;/mmc/d'|awk '!a[$0]++'|tr '\n' ':'|sed '$ s/:$//')
export PATH=${NEW_PATH}
LOGFILE=/koolshare/logs/remote_access_record.txt

mkdir -p /koolshare/logs

cmd() {
	"$@" 2>&1
	# ${@%%[[:space:]]*} ${@#*[[:space:]]} 2>&1
	# start-stop-daemon -S -b -x ${@%%[[:space:]]*} -- ${@#*[[:space:]]}
	# start-stop-daemon -S -x ss_config.sh -- start
}

clean_log() {
	[ $(wc -l "${LOGFILE}" | awk '{print $1}') -le "10000" ] && return
	local logdata=$(tail -n 2000 "${LOGFILE}")
	echo "$logdata" > ${LOGFILE} 2> /dev/null
	unset logdata
}

while read MSG;
do
	IP_CIDR=$(ip addr show br0 2>/dev/null | grep -E "inet " | awk '{print $2}')
	IP_ADDR=${IP_CIDR%/*}
	IP_ADDR=${IP_ADDR%.*}
	RET_0=$(echo "${REMOTE_ADDR}" | grep "${IP_ADDR}")
	RET_1=$(echo "${MSG}" | grep "ws_ok")
	if [ -z "${RET_0}${RET_1}" ];then
		# 非lan用户访问，记录下
		RET_2=$(echo ${MSG} | grep "ss_status")
		if [ -z "${RET_2}" ];then
			echo "[$(date -R +%Y年%m月%d日\ %X)] $REMOTE_ADDR:$REMOTE_PORT → ${MSG}" >>${LOGFILE}
			clean_log
		fi
	fi
	RET_3=$(echo "${MSG}" | grep -Ew "wget|curl|socat|nc|eval|ssh|scp|sed|awk|dropbear|dd|ln|rm|mv|cp|cd|aria2c|printf|openssl|base64|nvram|dbus|service|ps|ifconfig|ping|yaml|log")
	RET_4=$(echo "${MSG}" | grep -E ">|<")
	if [ "${MSG}" == "show_message" ]; then
		echo "成功连接到路由器，当前时间：$(date -R +%Y年%m月%d日\ %X)"
		echo "服务器：$SERVER_NAME"
		echo "客户端：$REMOTE_ADDR"
		echo "浏览器：$HTTP_USER_AGENT"
		echo "$(env)"
		echo "请点击下方按钮执行操作！"
	elif [ "${MSG}" == "reboot" ]; then
		echo "检测到你要执行路由器重启命令！拒绝！"
		exit
	elif [ "${MSG}" == "get_ssf_log" ]; then
		cat /tmp/upload/ssf_status.txt | /usr/bin/tr '\n' '@@'
	elif [ "${MSG}" == "get_real_log" ]; then
		_log=$(cat /tmp/upload/ss_log.txt)
		if [ -z "${_log}" ];then
			echo "开始获取日志！"
		else
			echo "${_log}"
		fi
	elif [ -n "${RET_3}" -o -n "${RET_4}" ]; then
		echo "不允许命令：${MSG}"
		exit
	else
		cmd $MSG
	fi
done


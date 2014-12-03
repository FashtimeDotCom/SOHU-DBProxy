#!/bin/bash

if [ "$AUTO_START" = "N" ]; then
  echo "must restart proxy"
  exit 1
fi
MYSQL_PROXY_RO_LB=wrr bash $SCRIPT_DIR/start_proxy.sh

### 1.1 添加用户 #####
mysql_cmd="$MYSQL -h $MYSQL_PROXY_ADMIN_IP -P $MYSQL_PROXY_ADMIN_PORT -u$MYSQL_PROXY_ADMIN_USER -p$MYSQL_PROXY_ADMIN_PASSWD -ABs -e"
check_sql="showusers"
_r=$($mysql_cmd $check_sql|grep proxy|grep $MYSQL_PROXY_WORKER_IP|wc -l)
if [ $_r = 0 ];then
	$mysql_cmd "AddUser --username=test --passwd=test --hostip=$MYSQL_PROXY_WORKER_IP"
	if [ $? != 0 ];then
		echo "add user error"
		exit 1
	fi
fi

### 1.2 设置账号连接限制 #######
$mysql_cmd "SetConnLimit --username=test --port-type=ro --hostip=$MYSQL_PROXY_WORKER_IP --conn-limit=0;"

### 1.3 将backend设置为offline
### 这个不好自动化 ### 也可以做 ####
### 相爱需要跑的测试用例 ####
$mysql_cmd "SetPoolConfig --username=test --port-type=ro --max-conn=2000 --min-conn=100 --save-option=mem"



t=$(
(
(
for i in {1..10000}; do
$MYSQL -h $MYSQL_PROXY_WORKER_IP -P $MYSQL_PROXY_RO_PORT -u test -ptest -ABs -e "show variables like 'wsrep_node_address'" &
done
) 2>&1 | sort | uniq -c
) 2>&1
)
declare -i t_1_no=0
declare -i t_2_no=0
t_1_no=$(echo "$t" | grep "X.X.X.X:5020" | awk '{print $1}')
t_2_no=$(echo "$t" | grep "X.X.X.X:5030" | awk '{print $1}')
if (( ( t_1_no + t_2_no == 10000 ) && ( t_1_no <= 8500 || t_1_no >= 7500 ) && ( t_2_no <= 2500 || t_2_no >= 1500 ) )); then
    ret=0
else
  echo "actual result: \"$t\""
  ret=1
fi


bash $SCRIPT_DIR/stop_proxy.sh

exit $ret
#eof

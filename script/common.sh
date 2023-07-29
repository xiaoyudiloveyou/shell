#!/bin/bash

# 开启extglob扩展
shopt -s extglob

# 日志文件路径
LOG_FILE="/opt/logfile.log"

trap "trapper" EXIT SIGINT SIGHUP

function trapper() {
  local status=$?
  [ "$status" -eq 5 ] && show_scp_help
}

# 定义log函数，接受两个参数：级别和消息
function log {
  local message="$1"
  local level="$2"
  [ -z "$level" ] && level="INFO"
  # ANSI颜色代码
  COLOR_RESET="\033[0m"
  COLOR_RED="\033[31m"
  COLOR_GREEN="\033[32m"
  COLOR_YELLOW="\033[33m"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  case "$level" in
  "INFO")
    echo -e "${COLOR_GREEN}[$level][$timestamp] $message${COLOR_RESET}"
    echo "[$level][$timestamp] $message" >>"$LOG_FILE"
    ;;
  "WARNING")
    echo -e "${COLOR_YELLOW}[$level][$timestamp] $message${COLOR_RESET}"
    echo "[$level][$timestamp] $message" >>"$LOG_FILE"
    ;;
  "ERROR")
    echo -e "${COLOR_RED}[$level][$timestamp] $message${COLOR_RESET}"
    echo "[$level][$timestamp] $message" >>"$LOG_FILE"
    ;;
  *)
    echo "Invalid log level: $level"
    ;;
  esac
}

## 使用log函数记录不同级别的日志，并输出到屏幕和日志文件
#log "INFO" "Starting the script..."
## 在这里可以添加你的主要任务逻辑
#log "WARNING" "Task 1 completed with warnings."
#
## 更多任务...
#log "ERROR" "Script encountered an error and terminated."
#
#log "INFO" "Script execution finished."
function show_scp_help() {
  cat <<EOF
  Usage: $0 [options]
  Options:"
    -h, --help      Show help message
    -a, --optionA   Perform option A action
    -b, --optionB   Perform option B action
EOF
}

function check_ip() {
  local ip=$1
  local ip_regex="^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})){3}$"
  local general_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
  if [[ ! "$address" =~ $general_ip_regex ]]; then
    log "$address 不是合法的IP地址" "ERROR"
    return 1
  fi
  if [[ ! "$address" =~ $ip_regex ]]; then
    log "$address 不是合法的IP地址" "ERROR"
    return 1
  fi
  return 0
}

function check_address() {
  local address=$1
  local hostname_regex="^[a-zA-Z][a-zA-Z0-9.-]{0,61}[a-zA-Z0-9]$"
  if [[ ! "$address" =~ $hostname_regex ]]; then
    check_ip "$address"
    [ "$?" -ne 0 ] && log "$address 不是合法的主机名地址" "ERROR" && return 1
  fi
  return 0
}

function check_path() {
  # 要判断的字符串
  local path="$1"
  local path_name="$2"
  # 定义合法路径的正则表达式
  valid_path_regex="^[a-zA-Z0-9./_-]+$"
  # 使用正则表达式匹配判断
  if [ -z "$path" ]; then
    log "路径为空." "ERROR"
    exit 1
  elif [[ ! "$path" =~ $valid_path_regex ]]; then
    log "$path 是非法路径." "ERROR"
    exit 1
  else
    path=$(readlink -f $path)
    eval "$path_name=$path"
    return 0
  fi
}

#  0 - 密码合法
#  1 - 密码长度不足要求
#  2 - 密码缺少不同类型的字符
#  3 - 密码包含常见的密码
#  4 - 密码包含个人信息
function validate_password() {
  local password="$1"

  # 密码长度要求
  local min_length=8
  # 密码包含不同类型的字符要求
  local has_uppercase=false
  local has_lowercase=false
  local has_digit=false
  local has_special=false
  # 密码是否包含常见的密码
  local common_passwords=("password" "123456" "qwerty" "abc123")
  # 密码中不能包含的个人信息
  local personal_info=("user" "name" "birthday" "phone")
  # 校验密码长度
  if [ ${#password} -lt $min_length ]; then
    log "密码长度不足要求"
    return 1
  fi
  # 校验密码是否包含不同类型的字符
  if [[ "$password" =~ [A-Z] ]]; then
    has_uppercase=true
  fi
  if [[ "$password" =~ [a-z] ]]; then
    has_lowercase=true
  fi
  if [[ "$password" =~ [0-9] ]]; then
    has_digit=true
  fi
  if [[ "$password" =~ [!@#\$%^\&*] ]]; then
    has_special=true
  fi
  if ! $has_uppercase || ! $has_lowercase || ! $has_digit || ! $has_special; then
    log "密码缺少不同类型的字符" "ERROR"
    return 2
  fi
  # 校验密码是否包含常见的密码
  for common_pass in "${common_passwords[@]}"; do
    if [ "$password" == "$common_pass" ]; then
      log "密码包含常见的密码" "ERROR"
      return 3
    fi
  done
  # 校验密码是否包含个人信息
  for info in "${personal_info[@]}"; do
    if [[ "$password" =~ $info ]]; then
      log "密码包含个人信息" "ERROR"
      return 4
    fi
  done
  log "密码合法"
  # 密码合法
  return 0
}

#function check_empty() {
#    local input="$1"
#    # 使用正则表达式匹配字符串是否为空或只包含空白字符
#    if [[ "$input" =~ ^[[:space:]]*$ ]]; then
#        return 0
#    else
#        log "输入 $input 为空" "ERROR"
#        return 1
#    fi
#}

function check_empty() {
  local count=0
  while [ $# -gt 0 ]; do
    local input="$1"
    string=$(eval echo $input)
    # 使用正则表达式匹配字符串是否为空或只包含空白字符
    if [[ "$string" =~ ^[[:space:]]*$ ]]; then
      log "输入 '${input#\$}' 为空" "ERROR"
      let count++
    fi
    shift
  done
  [ "$count" -ne 0 ] && return 1 || return 0
}

function expect_scp_command() {
  echo "${user_home}" | grep -q "~" && log "如果需要普通用户传输文件，需要源节点和目标节存在该用户：$target_user." "ERROR"
  expect 2>/dev/null <<EOF
      set timeout 3
      log_user 0
      spawn scp -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o NumberOfPasswordPrompts=1 -rp ${source_user}@${source_address}:${source_path} ${target_user}@${target_address}:${user_home}

        expect {
            "yes/no"    { send "yes\n";exp_continue }
            "password:" { send -- "${target_user_pwd}\n"; }
            "default"     { send_error "Failed\n";exit 1 }
        }

        expect {
            "yes/no"    { send "yes\n";exp_continue }
            "password:" { send -- "${target_user_pwd}\n"; }
            "default"     { send_error "Failed\n";exit 1 }
        }
      log_user 1
      expect eof
      catch wait result
      exit [lindex \$result 3]
EOF
  return $?

}

function expect_cmd_command() {
  expect 2>/dev/null <<EOF
  log_user 0
  spawn ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3  -o NumberOfPasswordPrompts=1 ${target_user}@${target_address}
          expect {
              "yes/no"    { send "yes\n";exp_continue }
              "password:" { send -- "${target_user_pwd}\n";exp_continue }
              "login" { send "su - root\n";}
              "default"     { send_error "Failed\n";exit 1 }
          }
          expect {
              "yes/no"    { send "yes\n";exp_continue }
              "Password:" { send -- "${target_root_pwd}\n";exp_continue }
              "login" { send "
chmod 755 ${user_home}/${source_path##*/}
chown root: ${user_home}/${source_path##*/}
mv -f ${user_home}/${source_path##*/} ${target_path}
exit 0
exit 0
"}
                "default"     { send_error "Failed\n";exit 1 }

          }
      expect eof
      catch wait result
      exit [lindex \$result 3]
EOF
}

function scp_debug() {
  [ "$1" == "false" ] && return 0
  log "source_path       :$source_path    "
  log "source_user       :$source_user    "
  log "source_address    :$source_address "
  log "source_user_pwd    :$source_user_pwd "
  log "source_root_pwd    :$source_root_pwd "
  log "target_path       :$target_path    "

  log "target_user       :$target_user    "
  log "target_address    :$target_address "
  log "target_user_pwd    :$target_user_pwd "
  log "target_root_pwd    :$target_root_pwd "
  #
  log "ywx --------------------------------"
}
function scp_file() {
  local user=""
  local address=""
  local input_path=""
  local user_pwd=""
  local user_root_pwd=""

  local source_path=""
  local source_user=""
  local source_address=""
  local source_user_pwd=""
  local source_root_pwd=""

  local target_path=""
  local target_user=""
  local target_address=""
  local target_user_pwd=""
  local target_root_pwd=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      show_scp_help
      exit 0
      ;;
    [a-zA-Z]*@*:*)
      user=$(echo "$1" | cut -d '@' -f 1)
      address=$(echo "$1" | cut -d '@' -f 2 | cut -d ':' -f 1)
      input_path=$(echo "$1" | cut -d '@' -f 2 | cut -d ':' -f 2)
      case $2 in
      -w | -W)
        user_root_pwd=$(echo "$3" | awk '{print $1}')
        user_pwd=$(echo "$3" | awk '{print $2}')
        shift
        shift
        ;;
      *)
        [ -z "$user_root_pwd" ] && log "你没有使用密码，请确保对目标节点设置免密"
        ;;
      esac
      ;;
    [a-zA-Z0-9.-]*:*)
      user="root"
      address=$(echo $1 | cut -d ':' -f 1)
      input_path=$(echo $1 | cut -d ':' -f 2)
      case $2 in
      -w | -W)
        user_root_pwd=$(echo "$3" | awk '{print $1}')
        user_pwd=$(echo "$3" | awk '{print $2}')
        shift
        shift
        ;;
      *)
        log "你没有使用密码，请确保对目标节点设置免密"
        ;;
      esac
      ;;
    /*[a-zA-Z0-9]*)
      user="root"
      address="127.0.0.1"
      input_path="$1"
      case $2 in
      -w | -W)
        user_root_pwd=$(echo "$3" | awk '{print $1}')
        user_pwd=$(echo "$3" | awk '{print $2}')
        shift
        shift
        ;;
      *)
        log "你没有使用密码，请确保对目标节点设置免密"
        ;;
      esac
      ;;
    *)
      echo "Invalid option dian 1: $1"
      exit 5
      ;;
    esac
    check_path "$input_path" "input_path"
    check_address "$address"
    [ -z "${user}" ] && log "输入用户非法" "ERROR"

    if [ -z "$source_path" ]; then
      source_path="$input_path"
      source_user="$user"
      source_address="$address"
      source_user_pwd="$user_pwd"
      source_root_pwd="$user_root_pwd"
    else
      target_path="$input_path"
      target_user="$user"
      target_address="$address"
      target_user_pwd="$user_pwd"
      target_root_pwd="$user_root_pwd"
    fi
    shift
  done
  log "---------------开始拷贝-----------------------"

  scp_debug "false"

  [ "$source_user" != "root" ] && [ -z "$source_user_pwd" ] && log "需要输入 source_user 普通用户密码。" "ERROR" && exit 1
  [ "$target_user" != "root" ] && [ -z "$target_user_pwd" ] && log "需要输入 target_user 普通用户密码。" "ERROR" && exit 1
  [ "$source_user" == "root" ] && [ -z "$source_user_pwd" ] && source_user_pwd=$source_root_pwd
  [ "$target_user" == "root" ] && [ -z "$target_user_pwd" ] && target_user_pwd=$target_root_pwd

  check_empty '$user_root_pwd' '$source_path' '$source_user' '$source_address' '$target_path' '$target_user' '$target_address'
  [ "$?" -ne 0 ] && exit 1
  local user_home=$(eval echo ~$target_user)
  expect_scp_command
  expect_cmd_command
  log "---------------拷贝完成-----------------------"
}

#scp_file "${source_path}" "${user}@${ip}:${target_path}" -w "${user_pwd} ${user_root_pwd}"

#scp_file /opt/common.sh xiaoyu@192.168.126.129:/opt/ -w "yujiale547 yujiale547"
scp_file "$@"

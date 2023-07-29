#!/bin/bash

function translate_str() {
    str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//\$/\\$}"
    str="${str//\[/\\[}"
    str="${str//\{/\\{}"
    str="${str//\}/\\\}}"
    echo "$str"
}

function scp_file() {
    chown "${user}:" ${source_path}
    expect 2>/dev/null <<EOF
    set timeout 3
    log_user 0
    spawn  scp  -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3  -o NumberOfPasswordPrompts=1 ${source_path} ${user}@${ip}:/home/${user}
    expect {
        "yes/no"    { send "yes\n";exp_continue }
        "password:" { send -- "${user_pwd}\n"; }
        default     { send_error "Failed\n";exit 1 }
    }
    send { "exit 0\n" }
    expect eof
    catch wait result
    exit [lindex \$result 3]
EOF
    return $?
}

function get_value() {
    expect 2>/dev/null <<EOF
    set timeout 3
    log_user 0
    spawn  ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3  -o NumberOfPasswordPrompts=1 ${user}@${ip}
    expect {
        "yes/no"    { send "yes\n";exp_continue }
        "password:" { send -- "${user_pwd}\n"; }
        default     { send_error "Failed\n";exit 1 }
    }
    expect "login"     { send "su - root \n" }
    log_user 1
    expect {
        "Password:" { send -- "${root_pw}\n";exp_continue }
        "login"     { send "echo value=\$\($bash_exec\) \n" }
        default    { send_error "Failed\n";exit 1 }
    }
    send "exit \r"
    send "exit \r"
    expect eof
    catch wait result
    exit [lindex \$result 3]
EOF
    return $?
}

function file_exec_trans() {
    local target_path="${bash_exec}"
    file_name="${target_path##*/}"
    source_path="./${file_name}"
    [ ! -f "${source_path}" ] && echo "请在当前目录下放入执行脚本"
    scp_file
    [ "$?" -ne 0 ] && echo "failed to scp file"
    bash_exec="
    chown root: /home/${user}/${file_name};
    mv -f /home/${user}/${file_name} ${target_path};
    bash ${target_path};
    "
}

function init() {
    user="$1" ip="$2" pw=("$3") bash_exec="$4"
    user_pwd="${pw[0]}" root_pw="${pw[1]}"
    [ -z "${root_pw}" ] && root_pw="${user_pwd}"
    root_pw=$(translate_str "$root_pw")
    user_pwd=$(translate_str "$user_pwd")
    bash_exec=$(translate_str "$bash_exec")
}
func() {
    cat <<EOF
        u) user;;
        i) ip=;;
        w) w=;;
        s) exec;;
        ?) func;;
EOF
}

function main() {
    bash_exec="uname"
    while getopts 'u:i:w:s:' OPT; do
        case $OPT in
        u) user="$OPTARG" ;;
        i) ip="$OPTARG" ;;
        w) pw="$OPTARG" ;;
        s) bash_exec="$OPTARG" ;;
        ?) func ;;
        esac
    done
    init "$@"
    if echo "${bash_exec}" | grep -qE ".sh$"; then
        file_exec_trans
    fi
    result=$(get_value | tr -s ' ' '\n' | grep "value=" | grep -v "value=\$.*" | cut -d'=' -f2 | sed -n '$p')
    [ "$?" -ne 0 ] && echo "failed to sdfg file"
    echo $result
}

#main $@
main "xiaoyu" "192.168.126.128" "yujiale547" "/opt/asdf.sh"
#main "xiaoyu" "192.168.126.128" "yujiale547" "hostname"

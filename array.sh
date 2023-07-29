#!/bin/bash
password=yujiale547

expect <<EOF
           log_user 0
           set timeout 3
           spawn ssh xiaoyu@192.168.126.128
           expect {
                 "yes/no" { send "yes\r"; exp_continue }
                 "password:" { send "$password\r";  }
           }
           expect {
                   "@*"   {send "su - root\r";exp_continue }
                   "Password:" {send "yujiale547\r";}
           }
           expect eof
           log_user 1
           send "hostname\r"
           expect eof
           log_user 0
           send "exit 0\r"
           send "exit 0\r"
           expect eof
           catch wait result
           exit [lindex \$result 3]
EOF

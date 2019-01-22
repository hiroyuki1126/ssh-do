#!/bin/bash

function error() {
    echo "ERROR: $(basename $0): $@" 1>&2
}

function abort() {
    error $@
    exit 1
}

[ $# -eq 1 ] || abort "Usage: $(basename $0) <server_list.txt>"
readonly input_file=$1
[ -r ${input_file} ] || abort "${input_file}: cannot access."

readonly script_url='https://raw.githubusercontent.com/hiroyuki1126/centos-setup/master/centos-setup.sh'
readonly exec_command="curl -sL ${script_url} | bash -x"

hostname=()
username=()
password=()
while read line; do
    data=(${line[@]})
    hostname=(${hostname[@]} ${data[0]})
    username=(${username[@]} ${data[1]})
    password=(${password[@]} ${data[2]})
done << FILE_CONTENTS
    $(grep -v -e '^\s*#' -e '^\s*$' ${input_file})
FILE_CONTENTS

for i in $(seq 0 $(expr ${#hostname[@]} - 1)); do
    read -p "#################### ${hostname[${i}]} #################### ok? (y/N): " yn
    case "${yn}" in
        [nN])
            continue
            ;;
        *)
            ;;
    esac

    expect -c "
    set timeout -1
    spawn ssh ${username[${i}]}@${hostname[${i}]}
    expect \"Are you sure you want to continue connecting (yes/no)?\" {
        send \"yes\n\"
        expect \"${username[${i}]}@${hostname[${i}]}'s password:\" {
            send \"${password[${i}]}\n\"
            expect \"\[#$%>\]\" {
                send \"${exec_command}\n\"
                send \"exit\n\"
            }
        }
    } \"${username[${i}]}@${hostname[${i}]}'s password:\" {
        send \"${password[${i}]}\n\"
        expect \"\[#$%>\]\" {
            send \"${exec_command}\n\"
            send \"exit\n\"
        }
    }
    interact
    "
    echo
done

exit 0

#!/bin/bash

function error() {
    echo "ERROR: $(basename $0): $@" 1>&2
}

function abort() {
    error $@
    exit 1
}

[ $# -eq 2 ] || abort "Usage: $(basename $0) <server_list> <script_file>"
readonly server_list=$1
readonly script_file=$2
[ -r ${server_list} ] || abort "${server_list}: cannot access."
[ -r ${script_file} ] || abort "${script_file}: cannot access."

data=()
while read line; do
    data+=("${line}")
done << FILE_CONTENTS
    $(grep -v -e '^\s*#' -e '^\s*$' ${server_list})
FILE_CONTENTS

[ "${data}" = "" ] && abort "${server_list}: file is empty."

cat ${script_file} || abort "cat ${script_file}: failed."

for ssh_info in "${data[@]}"; do
    si_array=(${ssh_info})
    if [ ${#si_array[@]} -lt 3 ]; then
        error "${server_list}: format is invalid. => ${ssh_info}"
        continue
    fi
    hostname=${si_array[0]}
    username=${si_array[1]}
    password=${si_array[2]}

    read -p "#################### ${hostname} #################### ok? (y/N): " yn
    case "${yn}" in
        [Nn]|[Nn][Oo])
            continue
            ;;
        *)
            ;;
    esac

    expect -c "
    set timeout -1
    spawn bash -c \"cat ${script_file} | ssh ${username}@${hostname} bash -x\"
    expect \"${username}@${hostname}'s password:\" {
        send \"${password}\n\"
        expect \"${username}@${hostname}'s password:\" {
            exit 1
        }
        exit 0
    } \"Are you sure you want to continue connecting (yes/no)?\" {
        send \"yes\n\"
        expect \"${username}@${hostname}'s password:\" {
            send \"${password}\n\"
            expect \"${username}@${hostname}'s password:\" {
                exit 1
            }
            exit 0
        }
    } \"Permission denied\" {
        exit 2
    } \"Connection refused\" {
        exit 3
    } \"Operation timed out\" {
        exit 4
    }
    exit 9
    "

    case $? in
        0)
            echo -e "\n-------------------- successfully exit. --------------------" 1>&2
            ;;
        1)
            echo -e "\n!!!!!!!!!!!!!!!!!!!! ERROR: username or password is incorrect. !!!!!!!!!!!!!!!!!!!!" 1>&2
            ;;
        2)
            echo -e "\n!!!!!!!!!!!!!!!!!!!! ERROR: Permission denied. !!!!!!!!!!!!!!!!!!!!" 1>&2
            ;;
        3)
            echo -e "\n!!!!!!!!!!!!!!!!!!!! ERROR: connection refused. !!!!!!!!!!!!!!!!!!!!" 1>&2
            ;;
        4)
            echo -e "\n!!!!!!!!!!!!!!!!!!!! ERROR: operation timed out. !!!!!!!!!!!!!!!!!!!!" 1>&2
            ;;
        *)
            echo -e "\n!!!!!!!!!!!!!!!!!!!! ERROR: abnormally exit. !!!!!!!!!!!!!!!!!!!!" 1>&2
            ;;
    esac
done

exit 0

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

hostname=()
username=()
password=()
while read line; do
    data=(${line[@]})
    hostname=(${hostname[@]} ${data[0]})
    username=(${username[@]} ${data[1]})
    password=(${password[@]} ${data[2]})
done << FILE_CONTENTS
    $(grep -v -e '^\s*#' -e '^\s*$' ${server_list})
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
    spawn bash -c \"cat ${script_file} | ssh ${username[${i}]}@${hostname[${i}]} bash\"
    expect \"Are you sure you want to continue connecting (yes/no)?\" {
        send \"yes\n\"
        expect \"${username[${i}]}@${hostname[${i}]}'s password:\" {
            send \"${password[${i}]}\n\"
        }
    } \"${username[${i}]}@${hostname[${i}]}'s password:\" {
        send \"${password[${i}]}\n\"
    }
    expect eof
    exit
    "
    echo
done

exit 0

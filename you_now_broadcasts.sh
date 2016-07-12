#!/bin/bash


# http://redsymbol.net/articles/bash-exit-traps/
# 
# Define a trap function, to intercept cntl-c and perform clean up operations
#
function finish() {
    echo "trap activated"
    read something
}
trap finish EXIT

echo "---- external script is running -----"


# Perform the work of actually downloading a user's past broadcast.
function downloadBroadcast()
{
    platform=$1
    user_name=$2
    file_name=$3
    hls=$4
    server=$5
    stream=$6
    session=$7

    if [ "${platform}" == "mac" ]; then
        echo "mac"
        if [[ "$hls" != "" ]]; then
            cd `pwd`; 
            ffmpeg -i "$hls"  -c copy "./videos/${user_name}/${file_name}" ; 
        else
            cd `pwd`; 
            rtmpdump -v -o "./videos/${user_name}/${file_name}" -r "$server$stream?sessionId=$session" -p "http://www.younow.com/"; 
        fi

    elif [ "${platform}" == "linux" ]; then
        echo "linux"

        $rtmp -v -o "./videos/${user_name}/${file_name}" -r "$server$stream?sessionId=$session" -p "http://www.younow.com/"; 
        bash; 
        exit
    else
        echo "Unknown or non-supported platform"
    fi
}

downloadBroadcast $1 $2 $3 $4 $5 $6 $7

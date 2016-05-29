#!/bin/bash

verbose=false

echo "+--------------------------------------------+"
echo "|        YouNow video downloader             |"
echo "+--------------------------------------------+"
echo "|       This script helps you download       |"
echo "|   YouNow.com broadcasts and live streams   |"
echo "+--------------------------------------------+"
echo "| 1.0   @nikisdro             [ 2015-07-25 ] |"
echo "|       * Windows script for YN downloading  |"
echo "|                                            |"
echo "| 1.1   truethug              [ 2016-02-05 ] |"
echo "|       * Extend script to linux/ mac        |"
echo "|                                            |"
echo "| 1.2   IcedPenguin           [ 2016-05-28 ] |"
echo "|       * Fix for new YN streaming format    |"
echo "|                                            |"
echo "+--------------------------------------------+"
echo ""
echo "Paste broadcast URL or username below (right click - Paste) and press Enter"
echo "Example 1: https://www.younow.com/example_user/54726312/1877623/1043/b/June..."
echo "Example 2: example_user"
echo ""
echo "This script relise on several binary files located in ./_bin. You are responsible "
echo "for finding these files. Apt-get or brew install them."
echo "    file: ffmpeg"
echo "    file: rtmpdump"
echo "    file: xidel"
echo "    file: wget"

# TODO - updated program flow
#   "URL or username (leave blank to quit):" 
#   "[LIVE] $url is broadcasting now! Start recording (Y/n)? "
#   "Broadcasts or Moments (b/m)?"
#   "You can download these [broadcasts|moments]:"
#   << present with list. >>
#   "Type comma separated numbers, \"all\" to download everything,"
#   " \"n\" to list next 10 broadcasts or leave blank to return: "
#
# TODO - extract program loop into series of functions


mac=`uname -a | grep -i darwin`
if [ "$mac"  != "" ]
then
    mydir="$(dirname "$BASH_SOURCE")"
    cd $mydir
    cp ./_bin/rtmpdump /usr/local/bin
    cp ./_bin/xidel /usr/local/bin
    cp ./_bin/wget /usr/local/bin
else
    rtmp="wine ./_bin/rtmpdump.exe"
    pid=`ps -p $$ -o ppid=`
    ppid=`ps -o ppid= $pid`
    terminal=`ps -p $ppid o args=`
    echo $terminal
fi

mkdir -p ./_temp
mkdir -p ./videos

# Function: Download a video.
# @param: user ame
# @param: video number (numeric order)
# @param: broadcast id
function downloadVideo()
{
    dir=$1_$2
    broadcast_id=$3

    mkdir -p ./_temp/$dir
    mkdir -p ./videos/$1

    wget --no-check-certificate -q http://www.younow.com/php/api/younow/user -O ./_temp/$dir/session.txt  
    wget --no-check-certificate -q http://www.younow.com/php/api/broadcast/videoPath/broadcastId=$broadcast_id -O ./_temp/$dir/rtmp.txt
    session=`xidel -q ./_temp/$dir/rtmp.txt -e '$json("session")'`
    server=`xidel -q ./_temp/$dir/rtmp.txt -e '$json("server")'`
    stream=`xidel -q ./_temp/$dir/rtmp.txt -e '$json("stream")'`
    hls=`xidel -q ./_temp/$dir/rtmp.txt -e '$json("hls")'`

    if $verbose ; then
        echo "--- stream information ---"
        echo "session: $session"
        echo "  sever: $server"
        echo " stream: $stream"
        echo "    hls: $hls"
        echo "--- stream information ---"
    fi

    # Ensure we don't over write existing files
    filename="${1}_${broadcast_id}_"
    extension=".mkv"
    append="a"
    
    while [ -e "${filename}${extension}" ]; do
        filename="${filename}${append}"
    done
    filename="${filename}${extension}"

    # Execute the command
    if [ "$mac" == "" ] 
    then
        $terminal -x sh -c "$rtmp -v -o ./videos/$1/$filename -r \"$server$stream?sessionId=$session\" -p \"http://www.younow.com/\";bash;exit"
    else
        if [[ "$hls" != "" ]]; then
            echo "cd `pwd`; ffmpeg -i \"$hls\"  -c copy \"./videos/$1/$filename\" ; read something "  > ./_temp/$filename.command
        else
            echo "cd `pwd`; rtmpdump -v -o ./videos/$1/$filename -r \"$server$stream?sessionId=$session\" -p \"http://www.younow.com/\"; read something" > ./_temp/$filename.command    
        fi
        
        chmod +x ./_temp/$filename.command
        open ./_temp/$filename.command
    fi
}

# Function: Download a moment (portion of a video).
# @param: user name
# @param: broadcast id
# @param: moment id
function downloadMoment() 
{
    user_name=$1
    broadcast_id=$2
    moment_id=$3

    mkdir -p ./videos/$user_name

    # Ensure we don't over write existing files
    filename="${user_name}_${broadcast_id}_moment_${moment_id}_"
    extension=".mkv"
    append="a"
    
    while [ -e "${filename}${extension}" ]; do
        filename="${filename}${append}"
    done
    filename="${filename}${extension}"

    # Execute the command
    if [ "$mac" == "" ] 
    then
        echo "Not implemented:"
        echo "  \"ffmpeg -i \"https://hls.younow.com/momentsplaylists/live/${moment_id}/${moment_id}.m3u8\"  -c copy \"./videos/$1/$filename\";\" "
    else
        echo "ffmpeg -i \"https://hls.younow.com/momentsplaylists/live/${moment_id}/${moment_id}.m3u8\"  -c copy \"./videos/$1/$filename\" ; read something"  > ./_temp/$filename.command

        chmod +x ./_temp/$filename.command
        open ./_temp/$filename.command
    fi

}

# ====== Main Program Loop ======
end="false"
while [ "$end" == "false" ]
do
    num1=1
    startTime=0
    ex="false"

    echo "URL or username (leave blank to quit):" 
    read url

    web=`echo $url | grep 'younow.com'`

    # ====== Download a Specific Address ======
    if [ "$web" != "" ]
    then
        user=`echo $url | cut -d'/' -f4`
        broadcast_id=`echo $url | cut -d'/' -f5`
        user_id=`echo $url | cut -d'/' -f6`

        downloadVideo "$user" "0" "$broadcast_id"

        echo " OK! Started downloading in a separate window."

        num1=$((num1 + 1))

    # ====== Download Videos for a Username ======
    elif [ "$url" != "" ]
    then
        wget --no-check-certificate -q http://www.younow.com/php/api/broadcast/info/user=$url -O ./_temp/$url.json

        echo ''

        user_id=`xidel -q ./_temp/$url.json -e '$json("userId")'`
        error=`xidel -q ./_temp/$url.json -e '$json("errorCode")'`

        if [ "$error" == "0" ]
        then

            # ====== Download the User's Live Stream ======
            echo "[LIVE] $url is broadcasting now! Start recording (Y/n)? "
            read input

            if [ "$input" != "n" ]
            then
                broadcast_id=`xidel -q ./_temp/$url.json -e '$json("broadcastId")'`
                temp=`xidel -q -e 'join(($json).media/(host,app,stream))' ./_temp/$url.json`
                host=`echo $temp | cut -d' ' -f1`
                app=`echo $temp | cut -d' ' -f2`
                stream=`echo $temp | cut -d' ' -f3`
                filename="$url\_live_$broadcast_id.flv"
                if [ ! -d ./videos/$url ]
                then
                    mkdir ./videos/$url
                fi

                if [ "$mac" == "" ]
                then
                    $terminal -x sh -c "$rtmp -v -o ./videos/$url/$filename -r rtmp://$host$app/$stream;bash"
                else
                    echo "cd `pwd` ; rtmpdump -v -o ./videos/$url/$filename -r rtmp://$host$app/$stream" > ./_temp/$filename.command
                    chmod +x ./_temp/$filename.command
                    open ./_temp/$filename.command
                fi
                echo " OK! Started recording in a separate window."
            else
                rm ./_temp/$url*.json 2>/dev/null
            fi

            echo "Continue working with $url (Y/n)"
            read input

            if [ "$input" == "n" ]
            then
                ex="true"
            fi
        fi

        # ====== Download the User's Past Streams ======
        idx=1
        unset videos
        while [ "$ex" == "false" ]
        do
            wget --no-check-certificate -q http://www.younow.com/php/api/post/getBroadcasts/startFrom=$startTime/channelId=$user_id -O ./_temp/$url\_json.json
            xidel -q -e '($json).posts().media.broadcast/join((videoAvailable,broadcastId,broadcastLengthMin,ddateAired),"-")' ./_temp/$url\_json.json > ./_temp/$url\_list.txt
            if [  -f ./_temp/$url\_list.txt ]
            then
                echo "You can download these broadcasts:"
                while read line 
                do
                    available=`echo $line|cut -d'-' -f1`
                    broadcast_id=`echo $line|cut -d'-' -f2`
                    length=`echo $line|cut -d'-' -f3`
                    ddate=`echo $line | cut -d'-' -f4`
                    if [ "$available" == "1" ]
                    then
                       current=""
                       echo $idx $length $ddate - $broadcast_id
                       videos[$idx]=$broadcast_id
                       idx=$((idx + 1))
                    fi
                done < ./_temp/$url\_list.txt

                echo "Type comma separated numbers, \"all\" to download everything,"
                echo "\"n\" to list next 10 broadcasts or leave blank to return: "
                read input      

                if [ "$input" == "" ]
                then
                    ex="true"
                elif [ "$input" == "n" ]
                then  
                    startTime=$(( startTime  + 10 ))
                else
                    if [ "$input" == "all" ]
                    then
                        for i in `seq 1 ${#videos[@]}`
                        do
                            downloadVideo "$url" "$i" "${videos[$i]}"
                        done
                    fi

                    while [ "$input" != "$current" ]
                    do
                        current=`echo $input | cut -d',' -f1`
                        input=`echo $input | cut -d',' -f2-`  
                        downloadVideo "$url" "$num1" "${videos[$current]}"
                        num1=$((num1 + 1))
                    done
                    startTime=$(( startTime  + 10 ))
                fi 
            else
                echo " - There's nothing to show."
                ex="true"
            fi
        done

        startTime=0
    else
        end="true"
    fi
done

rm -rf ./_temp/* 2>/dev/null

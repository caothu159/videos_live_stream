#!/usr/bin/env bash
#!/bin/bash

__loop() {
    local total=$(ls /var/www/videos/media | grep -v .sh | wc -l)
    local index=${1:-0}
    local video=$(ls /var/www/videos/media | grep -v .sh | head -n $(($index + 1)) | tail -1)
    local vpath=/var/www/videos/media/$video
    echo "playing $vpath"
    local streampath=${1:-'unicast/c1/s0/live'}
    local type=${2:-'main'}
    # ffmpeg -re -i $vpath -c copy -f rtsp rtsp://171.244.62.193:554/test
    # ffmpeg -re -i /var/www/videos/1981Lofi_nhacxua8x9x.mp4 -c:v libx264 -c:a copy -f rtsp://171.244.62.193:554/video
    # ffmpeg -re -i /var/www/videos/1981Lofi_nhacxua8x9x.mp4 -preset ultrafast -c copy -c:v libx264 -c:a aac -f rtsp -rtsp_transport tcp -muxdelay 0.1 rtsp://171.244.62.193:554/video
    __main() {
        ffmpeg -re -i $vpath -preset slow \
            -s 1280x720 -r 25 -c:v libx264 -g 15 -b:v 1150k -maxrate:v 1150k -minrate:v 0k \
            -c:a aac \
            -f rtsp rtsp://171.244.62.193:554/$streampath
    }

    __sub() {
        ffmpeg -re -i $vpath -preset slow \
            -s 352x288 -r 15 -c:v libx264 -g 15 -b:v 1150k -maxrate:v 1154k -minrate:v 0k \
            -c:a aac \
            -f rtsp rtsp://171.244.62.193:554/$streampath
    }

    "__$type"

    sleep 0.3
    __loop $((($index + 1) % $total))
}

__service() {
    # cat
    cat | sudo tee /etc/systemd/system/ductn_rtsp.service <<-EOF
[Unit]
Description=Ductn RTSP client

[Service]
ExecStart=/var/www/videos/ductn_rtsp.sh
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
}

__install() {
    wget https://github.com/bluenviron/mediamtx/releases/download/v1.1.1/mediamtx_v1.1.1_linux_amd64.tar.gz -O mediamtx.tar.gz
    tar -xvf mediamtx_v1.1.1_linux_amd64.tar.gz
    sudo cp mediamtx /usr/local/bin/
    sudo cp mediamtx.yml /usr/local/etc/
}

__config() {
    sudo tee /etc/systemd/system/mediamtx.service >/dev/null <<EOF
[Unit]
Wants=network.target
Description=Ductn RTSP server

[Service]
ExecStart=/usr/local/bin/mediamtx /usr/local/etc/mediamtx.yml
[Install]
WantedBy=multi-user.target
EOF

    local match="########## DUCTN Media server ##########"
    local cnf_path=/usr/local/etc/mediamtx.yml
    local cdir=$(dirname $(realpath "$BASH_SOURCE"))
    local match_index=$(grep "$match" $cnf_path | wc -l)

    sudo touch $cnf_path
    if [[ $match_index == 0 ]]; then
        echo $match | sudo tee -a $cnf_path >/dev/null
        echo $match | sudo tee -a $cnf_path >/dev/null
    elif [[ $match_index == 1 ]]; then
        sudo sed -i "/$match/a\\$match" $cnf_path
    fi

    local content=$(cat $cdir/ductn_mediamtx.yml)

    echo "$content" | sudo sed -i -e "/$match/{:a;N;/\n$match$/!ba;r /dev/stdin" -e ";d}" $cnf_path
    sudo cat /usr/local/etc/mediamtx.yml >mediamtx.yml
}

__run() {
    sudo systemctl daemon-reload
    sudo systemctl enable mediamtx
    sudo systemctl restart mediamtx
}

__stop() {
    sudo systemctl stop mediamtx
}

__log() {
    sudo journalctl -u mediamtx.service -f
}

__port() {
    sudo lsof -nP | grep LISTEN
}

if [[ -n $* ]]; then
    "__$@"
    exit
fi

__loop

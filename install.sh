#!/bin/bash
export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

red() {
    echo -e "\033[31m\033[01m$*\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$*\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$*\033[0m"
}


function common_command() {
    server_ip=$(curl -s https://ipinfo.io/ip)
    cloud=$(curl -s ipinfo.io/$server_ip/org|awk '{print $2}')
    city=$(curl -s ipinfo.io/$server_ip/city)
    uuid=$(/usr/bin/sing-box generate uuid)
    hn=$(hostname)
    password=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)

    key_pair=$(/usr/bin/sing-box generate reality-keypair)

    private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')

    public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

    short_id=$(/usr/bin/sing-box generate rand --hex 8)
}

function check_config_exit() {
    conf_file="/usr/local/etc/sing-box/$1.json"
    if [[ -e $conf_file ]]; then
        yellow "配置文件已存在，重新配置请删除: $conf_file"
        exit 1
    fi
}

function gen_url_qr() {
    green "1、粘贴URL添加节点"
    echo ""

    yellow "$*"

    green "2、扫描二维码添加节点"
    echo ""

    qrencode -t ANSIUTF8 "$*"
}

function check_config_validate() {
    conf_file="/usr/local/etc/sing-box/$1.json"

    /usr/bin/sing-box check -c $conf_file

    if [[ $? != 0 ]]; then
        red 配置文件不正确，请检查: $conf_file。
        exit 2
    fi
}

function uninstall_sing_box() {
    rm /usr/bin/sing-box
    rm /etc/systemd/system/sing-box.service
    rm -rf /usr/local/etc/sing-box
    echo -e "卸载完成"
}

function restart_sing_box {
    systemctl restart sing-box.service
}

function install_sing_box() {
    apt update
    apt install -yqq qrencode net-tools
    
    latest_version_tag=$(curl -s "https://api.github.com/repos/xxf185/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
    latest_version=${latest_version_tag#v}
    echo "Latest version: $latest_version"

    arch=$(uname -m)
    echo "Architecture: $arch"

    case ${arch} in
    x86_64)
        arch="amd64"
        ;;
    aarch64)
        arch="arm64"
        ;;
    armv7l)
        arch="armv7"
        ;;
    esac

    package_name="sing-box-${latest_version}-linux-${arch}"

    url="https://github.com/xxf185/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"

    curl -sLo "/tmp/${package_name}.tar.gz" "$url"

    tar -xzf "/tmp/${package_name}.tar.gz" -C /tmp
    mv "/tmp/${package_name}/sing-box" /usr/bin/sing-box

    rm -r "/tmp/${package_name}.tar.gz" "/tmp/${package_name}"

    chown root:root /usr/bin/sing-box
    chmod +x /usr/bin/sing-box

    mkdir -p /usr/local/etc/sing-box
    echo -e "{\n\n}" >/usr/local/etc/sing-box/config.json
    echo "[Unit]
    Description=sing-box service
    Documentation=https://sing-box.sagernet.org
    After=network.target nss-lookup.target

    [Service]
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
    AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
    ExecStart=/usr/bin/sing-box -C /usr/local/etc/sing-box run
    ExecReload=/bin/kill -HUP $MAINPID
    Restart=on-failure
    RestartSec=10s
    LimitNOFILE=infinity

    [Install]
    WantedBy=multi-user.target" | tee /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    green 安装sing-box完成！
}

function restart() {
    systemctl restart sing-box.service
    sleep 2
    systemctl status sing-box.service --no-pager -l
}

function test() {
    green "begin"
    check_config_exit test
    green "end"
}

function hy2() {

    conf_name="hy2"
    check_config_exit $conf_name
    common_command
    sni="bing.com"
    masquerade="https:\/\/bing.com"

    mkdir -p /etc/hysteria && openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key && openssl req -new -x509 -days 3650 -key /etc/hysteria/private.key -out /etc/hysteria/cert.pem -subj "/CN=bing.com"

    wget -O /usr/local/etc/sing-box/$conf_name.json https://raw.githubusercontent.com/xxf185/sb-hy2/refs/heads/main/config.json

    sed -i "s/PASSWORD/$password/g; s/SNI/$masquerade/g" /usr/local/etc/sing-box/$conf_name.json

    cat /usr/local/etc/sing-box/$conf_name.json

    server_link="hysteria2://$password@$server_ip:10003?insecure=1&obfs=none&sni=$sni#hy2"

    check_config_validate $conf_name
    restart

    gen_url_qr $server_link
}

function view_hysteria_config() {
    gen_url_qr $server_link 
}

function menu() {
    while true; do
        echo -e ""
        echo -e "-----------------Sing-Box-hysteria2-----------------"
        echo -e ""
        echo -e " ${GREEN}1.${PLAIN} 安装 Sing-Box"
        echo -e " ${GREEN}2.${PLAIN} 卸载 Sing-Box"
        echo -e " ${GREEN}3.${PLAIN} 配置 Hysteria2"
        echo -e " ${GREEN}4.${PLAIN} 查看配置"
        echo -e " ${GREEN}5.${PLAIN} 重启 Sing-Box"
        echo -e " ${GREEN}0.${PLAIN} 退出脚本"
        echo -e ""
        read -rp "选项: " menuInput
        case $menuInput in
        1) install_sing_box ;;
        2) uninstall_sing_box ;;
        3) hy2 ;;
        4) view_hysteria_config ;;
        5) restart_sing_box ;;
        99) test ;;
        *) exit 0 ;;
        esac
    done
}

menu

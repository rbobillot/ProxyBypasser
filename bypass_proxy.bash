#!/bin/bash

# This script is made to bypass proxy problems
# You can connect to ssh server through proxy thanks to corkscrew
# And then forward your port for your localhost, and use it on your web browser

cork_config_file="$HOME/.ssh/cork.auth"
ssh_config_file="$HOME/.ssh/config"

hostname=""
port=""
user=""

ssh_host="bypass"

dynamic_forward=4243

noproxy=$(env | grep -i no_proxy | head -1 | cut -d '=' -f2)
proxy=$(env | grep -i http_proxy | sed -e "s/.*=http:\/\/\(.*\):\(.*\)@\(.*\):\(.*\)/\1 \2 \3 \4/g")
read proxy_login proxy_password proxy_host proxy_port <<< `echo $proxy`

configure_cork_auth() {
	printf "\e[93mYour proxy login\e[0m [$proxy_login]: "
	read p_login
	[[ $p_login ]] && proxy_login="$p_login"

	printf "\e[93mYour proxy password\e[0m [$proxy_password]: "
	read p_password
	[[ $p_password ]] && proxy_password="$p_password"

	echo "$proxy_login:$proxy_password" > $cork_config_file \
		&& printf "\e[92mCork config file (\e[0m$cork_config_file\e[92m) correctly filled\e[0m\n" \
		|| (printf "\e[91mSomething went wrong while filling cork config file\e[0m\n" && ls /nop 2> /dev/null)
}

set_server_hostname() {
	printf "\e[96m\nYour server's hostname (IP or domain):\e[0m "
	read s_hostname
	[[ $s_hostname ]] && hostname=$s_hostname || set_server_hostname
	[[ `curl -s --head $hostname | grep 404` ]] \
		&& printf "\e[91mError: $hostname: cannot resolve hostname\e[0m" \
		&& set_server_hostname
}

set_server_port() {
	printf "\e[96mIts custom SSH listening port:\e[0m "
	read s_port
	[[ $s_port ]] && port=$s_port || set_server_port
}

set_server_username() {
	printf "\e[96mYour SSH username:\e[0m "
	read s_username
	[[ $s_username ]] && user=$s_username || set_server_username
}

configure_ssh_config() {
	set_server_hostname
	set_server_port
	set_server_username

	printf "\e[96mThe dynamic forward port you want\e[0m [$dynamic_forward]: "
	read df
	[[ $df ]] && dynamic_forward="$df"

	printf "\e[93m\nYour ssh host\e[0m [$ssh_host]: "
	read s_host
	[[ $s_host ]] && ssh_host="$s_host"

	printf "\e[93mThe proxy hostname\e[0m [$proxy_host]: "
	read p_host
	[[ $p_host ]] && proxy_host="$p_host"

	printf "\e[93mThe proxy port\e[0m [$proxy_port]: "
	read p_port
	[[ $p_port ]] && proxy_port="$p_port"

	echo -e "
Host $ssh_host
  HostName $hostname
  Port $port
  User $user
  DynamicForward $dynamic_forward
  ProxyCommand corkscrew $proxy_host $proxy_port %h %p $cork_config_file\n" >> $ssh_config_file \
		&& printf "\e[92mSSH config file (\e[0m$ssh_config_file\e[92m) correctly filled\e[0m\n\n" \
		|| (printf "\e[91mSomething went wrong while filling SSH config file\e[0m\n" && ls /nop 2> /dev/null)
}

update_firefox_settings() {
	ff_conf_file=`find $HOME -type f -iname 'prefs.js' | grep 'mozilla/firefox'`
	if [[ -f $ff_conf_file ]] ; then
		kill -9 `pgrep firefox` > /dev/null 2>&1
		printf "\e[95m\nSetting firefox to connect via dynamic forward...\e[0m\n"
		up_mode=1
		up_host=localhost
		up_port=$dynamic_forward
		up_np=$noproxy
		sed -ie "s/\(user_pref(\"network.proxy.type\"\,\).*/\1 $up_mode);/g" $ff_conf_file
		sed -ie "s/\(user_pref(\"network.proxy.socks\"\,\).*/\1 \"$up_host\");/g" $ff_conf_file
		sed -ie "s/\(user_pref(\"network.proxy.socks_port\"\,\).*/\1 $up_port);/g" $ff_conf_file
		sed -ie "s/\(user_pref(\"network.proxy.no_proxies_on\"\,\).*/\1 \"$up_np\");/g" $ff_conf_file
		#rm "${ff_conf_file}e" # remove sed backup
		firefox > /dev/null 2>&1 &
	fi
}

launch_test_ssh_connection() {
	printf "\e[96m\nTrying to connect to $hostname\e[0m (using the command: \e[93mssh $ssh_host\e[0m)...\n"
	printf "\e[96mDo not close the session until you're done with web browsing\e[0m...\n"
	ssh $ssh_host
}

install_binaries() {
	printf "\e[33m\nInstalling needed binaries\e[0m...\n"
	manager="apt-get"
	[[ `which apt` ]] && manager="apt"
	[[ `which brew` ]] && manager="brew"
	[[ `which curl` ]] && echo "curl is already installed" || sudo $manager install curl
	[[ `which corkscrew` ]] && echo "corkscrew is already installed" || sudo $manager install corkscrew
}

bypass_proxy() {
	printf "\e[93mFirst of all, you need an SSH access to a distant server,\n"
	printf "it must be listening on a port that is not 22.\n\n"
	printf "Also, you need to have Firefox installed (\e[91mwhich will be killed before setup\e[93m).\n\n"
	printf "Are you good to go ?\e[0m (y/n) "
	read answer

	if [[ $answer == 'y' ]]; then
		mkdir -p "$HOME/.ssh"
		install_binaries
		configure_ssh_config \
			&& configure_cork_auth \
			&& update_firefox_settings \
			&& launch_test_ssh_connection
	elif [[ $answer == 'n' ]]; then
		exit
	else
		bypass_proxy
	fi
}

bypass_proxy

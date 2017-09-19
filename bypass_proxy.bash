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
remote_forward=4242
local_ssh=22

noproxy=$(env | grep -i no_proxy | head -1 | cut -d '=' -f2)
proxy=$(env | grep -i http_proxy | head -1 | sed -e "s/.*=http:\/\/\(.*\):\(.*\)@\(.*\):\(.*\)/\1 \2 \3 \4/g")
read proxy_login proxy_password proxy_host proxy_port <<< `echo $proxy`

configure_cork_auth() {
	printf "\e[93mYour proxy login\e[0m [$proxy_login]: "
	read p_login && [[ $p_login ]] && proxy_login="$p_login"

	printf "\e[93mYour proxy password\e[0m [$proxy_password]: "
	read p_password && [[ $p_password ]] && proxy_password="$p_password"

	echo "$proxy_login:$proxy_password" > $cork_config_file \
		&& printf "\e[92mCork config file (\e[0m$cork_config_file\e[92m) correctly filled\e[0m\n" \
		|| (printf "\e[91mSomething went wrong while filling cork config file\e[0m\n" && ls /nop 2> /dev/null)
}

set_server_hostname() {
	printf "\e[96mYour server's hostname (IP or domain):\e[0m "
	read s_hostname && [[ $s_hostname ]] && hostname=$s_hostname || set_server_hostname
	[[ `curl -s --head $hostname | grep 404` ]] \
		&& printf "\e[91mError: $hostname: cannot resolve hostname\e[0m\n" \
		&& set_server_hostname
}

set_server_port() {
	printf "\e[96mIts custom SSH listening port:\e[0m "
	read s_port && [[ $s_port ]] && port=$s_port || set_server_port
}

set_server_username() {
	printf "\e[96mYour SSH username:\e[0m "
	read s_username && [[ $s_username ]] && user=$s_username || set_server_username
}

check_ssh_config_availability() {
	[[ `grep $1 $ssh_config_file` != "" ]] && printf "$1 - \033[91mnot available\033[0m"
}

set_dynamic_forward() {
	c_dynamic_forward=$dynamic_forward
	[[ `grep $dynamic_forward $ssh_config_file` != "" ]] && c_dynamic_forward="$dynamic_forward - \033[91mnot available\033[0m"
	printf "\e[96mThe dynamic forward (internet vpn) port you want\e[0m [$c_dynamic_forward]: "
	read df && [[ $df ]] && dynamic_forward="$df"
}

set_remote_forward() {
	c_remote_forward=$remote_forward
	[[ `grep $remote_forward $ssh_config_file` != "" ]] && c_remote_forward="$remote_forward - \033[91mnot available\033[0m"
	printf "\e[96mThe remote forward (reverse ssh tunnel) port you want\e[0m [$c_remote_forward]: "
	read rf && [[ $rf ]] && remote_forward="$rf"
}

set_ssh_host() {
	c_ssh_host=$ssh_host
	[[ `grep $ssh_host $ssh_config_file` != "" ]] && c_ssh_host="$ssh_host - \033[91mnot available\033[0m"
	printf "\e[93m\nYour ssh host\e[0m [$c_ssh_host]: "
	read s_host && [[ $s_host ]] && ssh_host="$s_host"
}

check_local_ssh_port_availability() {
	nc -z localhost $1
	[[ $? -eq 1 ]] && c_local_ssh=`printf "$1 - \033[91mnot available\033[0m"`
}

setup_reverse_tunnel() {
	choice="y"
	printf "Do you want to configure a reverse SSH tunnel ? [Y/n] "
	read c
	[[ $c ]] && choice=`printf $c | tr '[:upper:]' '[:lower:]'`
	if [[ $choice == "n" ]] ; then exit
	elif [[ $choice == "y" ]] ; then
		set_remote_forward

		c_local_ssh=$local_ssh
		check_local_ssh_port_availability $c_local_ssh
		# if $local_ssh port is not listening, $c_local_ssh will be red, else white
		printf "\e[96mThe ssh listening port of your localhost\e[0m [$c_local_ssh]: "
		read ls && [[ $ls ]] && local_ssh="$ls"
	else setup_reverse_tunnel
	fi
}

configure_ssh_config() {
	set_server_hostname
	set_server_port
	set_server_username

	set_dynamic_forward

	setup_reverse_tunnel

	set_ssh_host

	printf "\e[93mThe proxy hostname\e[0m [$proxy_host]: "
	read p_host && [[ $p_host ]] && proxy_host="$p_host"

	printf "\e[93mThe proxy port\e[0m [$proxy_port]: "
	read p_port && [[ $p_port ]] && proxy_port="$p_port"

	echo -e "\nHost $ssh_host"                                     >> $ssh_config_file && \
	echo -e "  HostName $hostname"                                 >> $ssh_config_file && \
	echo -e "  Port $port"                                         >> $ssh_config_file && \
	echo -e "  User $user"                                         >> $ssh_config_file && \
	echo -e "  DynamicForward $dynamic_forward"                    >> $ssh_config_file && \
	echo -e "  RemoteForward $remote_forward localhost:$local_ssh" >> $ssh_config_file && \
	echo -e "  ProxyCommand corkscrew $proxy_host $proxy_port %h %p $cork_config_file\n" >> $ssh_config_file \
		&& printf "\e[92mSSH config file (\e[0m$ssh_config_file\e[92m) correctly filled\e[0m\n\n" \
		|| (printf "\e[91mSomething went wrong while filling SSH config file\e[0m\n" && ls /nop 2> /dev/null)
}

update_firefox_settings() {
	ff_conf_file=`find $HOME -type f -iname 'prefs.js' | grep 'mozilla/firefox'`
	if [[ -f $ff_conf_file ]] ; then
		sudo kill -9 `pgrep firefox` > /dev/null 2>&1
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
	[[ `which apt` ]]       && manager="apt"
	[[ `which brew` ]]      && manager="brew"
	[[ `which curl` ]]      && echo "curl is already installed"      || sudo $manager install curl
	[[ `which corkscrew` ]] && echo "corkscrew is already installed" || sudo $manager install corkscrew
	echo
}

bypass_proxy() {
	printf "\ec\e[93mFirst of all, you need an SSH access to a distant server,\n"
	printf "it must be listening on a port that is not 22.\n\n"
	printf "Also, you need to have Firefox installed (\e[91mwhich will be killed before setup\e[93m).\n\n"
	printf "Are you good to go ?\e[0m [Y/n] "
	answer='y'
	read ans
	[[ $ans ]] && answer=`printf $ans | tr '[:upper:]' '[:lower:]'`

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

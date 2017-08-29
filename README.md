# ProxyBypasser
A Linux Bash Script to connect via SSH through proxy, and allow unlimited web browsing (thanks to corkscrew)

---

## Run with:
```
bash <(curl -sSL https://goo.gl/PDqiRb)
```
or clone the repo, and just run with:
```bash bypass_proxy.bash```

---

### What is it ?
Proxies can be great, but at work, it often sucks (blocked SSH connections, limited web browsing...)

Thanks to Pat Padgett, a wonderful tool exists to use SSH through proxy: corkscrew.

It is simple to use, but you have to write some config (if you know what you're doing, it's fine. If you're a newbie, it's cool to use have it all installed and configured)


So I did this little script, that will install and configure corscrew and Firefox so you can SSH to any server you own, and browse the web via your SSH connection.


### How to ?
  - First, you must have an SSH access to a distant server
  - It can be listening on port 22, but SSH also needs to listen to another port (you must configure your server) -> often, port 22 is filtered by proxy
  - Then you just have to follow instructions when the script is running
    * It will ask you some infos about your server (hostname, ssh port, user, DynamicForward port (Firefox will access the web through your server, via `localhost:dynamic_forward_port`))
    * You will be asked for you "ssh host", so you're able to connect with the command: `ssh host`. Example, for the server 'foobar.net', you set your ssh host as 'hello', so you can connect to foobar.net, via the command: `ssh hello`
    * Then it will ask infos about your proxy at work (hostname, port, login, password)
    * 2 files will be filled: ~/.ssh/cork.auth (with this: "proxy_user:proxy_pass"), ~/.ssh/config (with infos about your server, and your proxy)
    * It will kill Firefox, and configure its proxy settings (Preferences > Advanced > Network > Settings), by modifying the file: `~/.mozilla/firefox/*.default/prefs.js`
    * Finally, Firefox will be relaunched (in a back-process), and the script will connect your server via SSH. YOU MUST CONNECT (enter your SSH password) in terminal, before using Firefox

Enjoy :)

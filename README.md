# Nmapauto
A Bash script to fascilitate your Hacking journey

## Features
- The script will first do a verbose portscan, letting **you know instantly** if a port is open
- While you're checking some open port `ex:80`, the script will perform version & script scans only on open ports **saving you enough time**
- Scan results will automatically be saved to a **easy to locate** file

### Demo scan
Scan on a HTB macine
![Nmap-Automater](https://user-images.githubusercontent.com/70033863/157475666-f9127ad1-e7b9-473b-8a74-aea6e2dfa2f2.png)

## Install
Clone the repo
```sh
git clone https://github.com/the-root-user/nmap-auto.git
```
then, execute the command
```sh
sudo cp nmap-auto.sh /bin/nmapauto
```
or tweak a bit and add the one liner to your `.bashrc`/`.zshrc` as a function.
### Usage
`sudo nmapauto <target>`

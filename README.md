# Nmap-auto
A Bash script to fascilitate your Hacking journey

## Features
- The script will first do a verbose portscan, letting **you know instantly** if a port is open
- While you're checking some open port `ex:80`, the script will perform version & script scans only on open ports **saving you enough time**
- Scan results will automatically be saved to a **easy to locate** file
### Demo scan
Scan on **Paper** HTB macine
![Nmap-Automater](https://user-images.githubusercontent.com/70033863/157312380-b5f6489b-64ff-4712-b029-73904c5264d2.png)


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

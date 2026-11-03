# Nmapauto

A Bash script to facilitate your hacking and reconnaissance journey.

## Features

- **Fast & Verbose Discovery:** Performs a fast port scan first, displaying open ports in real-time as they are discovered.
- **Targeted Version & Script Scanning:** Executes targeted service and script scans (`-sC -sV`) only on discovered open ports, saving substantial time.
- **Top UDP Port Scanning:** Optionally conducts UDP scanning against top ports once TCP enumeration finishes.
- **Organized Results:** Scan results are automatically saved to easy-to-locate output files.
- **Configurable Options:** Customize output directory, packet rates, timing templates, custom port ranges, and toggles for UDP or colorized output.

### Demo scan

Scan on a Hack The Box machine:

![Nmap-Automater](https://user-images.githubusercontent.com/70033863/157475666-f9127ad1-e7b9-473b-8a74-aea6e2dfa2f2.png)

## Installation

Clone the repository:

```sh
git clone https://github.com/the-root-user/nmap-auto.git
cd nmap-auto
```

Install to your executable path:

```sh
sudo install -m 755 nmap-auto.sh /usr/local/bin/nmapauto
```

Or add an alias/function to your `~/.bashrc` or `~/.zshrc`.

## Usage

```sh
sudo nmapauto [OPTIONS] <target>
```

### Options

| Option | Description | Default |
| --- | --- | --- |
| `-o, --output-dir <dir>` | Directory to save scan results | `.` (current directory) |
| `-r, --rate <rate>` | Minimum packet rate for initial port scan | `1000` |
| `-T, --timing <0-5>` | Nmap timing template | `4` |
| `-p, --ports <range>` | Port range to scan in initial discovery | `-` (all 65535 ports) |
| `-Pn, --skip-ping` | Treat target as online, skipping host discovery | Disabled |
| `--no-udp` | Skip UDP port scan | Disabled |
| `--no-color` | Disable colorized terminal output | Disabled |
| `-v, --version` | Display script version | |
| `-h, --help` | Display help message and exit | |

### Examples

Basic full-port TCP and UDP scan:
```sh
sudo nmapauto 10.10.10.10
```

Scan and save results to a dedicated directory without UDP:
```sh
sudo nmapauto -o ./scans --no-udp 10.10.10.10
```

Scan specific ports with ping probe disabled:
```sh
sudo nmapauto -p 1-10000 -Pn 192.168.1.50
```

Fast scan with custom packet rate:
```sh
sudo nmapauto -r 2500 -T4 10.10.10.10
```

#!/usr/bin/env bash
#
# nmap-auto: Automated Nmap reconnaissance script
#

set -eo pipefail

VERSION="1.1.0"

# Defaults
TARGET=""
OUTPUT_DIR="."
MIN_RATE=1000
TIMING="4"
PORT_RANGE="-"
SKIP_UDP=false
SKIP_PING=false
USE_COLOR=true

# Check if stdout is a terminal for colors
if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
    USE_COLOR=false
fi

setup_colors() {
    if [[ "$USE_COLOR" == true ]]; then
        COLOR_RESET='\033[0m'
        COLOR_GREEN='\033[32m'
        COLOR_MAGENTA='\033[35m'
        COLOR_BLUE='\033[34m'
        COLOR_RED='\033[31m'
        COLOR_YELLOW='\033[33m'
    else
        COLOR_RESET=''
        COLOR_GREEN=''
        COLOR_MAGENTA=''
        COLOR_BLUE=''
        COLOR_RED=''
        COLOR_YELLOW=''
    fi
}

log_info() {
    echo -e "${COLOR_BLUE}- $1${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}- $1${COLOR_RESET}"
}

log_warn() {
    echo -e "${COLOR_YELLOW}- $1${COLOR_RESET}" >&2
}

log_error() {
    echo -e "${COLOR_RED}- $1${COLOR_RESET}" >&2
}

print_banner() {
    log_info "nmap-auto v${VERSION} - Automated Nmap Scanning"
}

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") [OPTIONS] <target>

Arguments:
  <target>                     Target IP address or hostname

Options:
  -o, --output-dir <dir>       Directory to save scan results (default: current directory)
  -r, --rate <rate>            Minimum packet rate for initial port scan (default: 1000)
  -T, --timing <0-5>           Nmap timing template (default: 4)
  -p, --ports <range>          Ports to scan in initial discovery (default: - for all ports)
  -Pn, --skip-ping             Treat target as online, skipping host discovery
      --no-udp                 Skip UDP scan
      --no-color               Disable colorized terminal output
  -v, --version                Display script version
  -h, --help                   Display this help message

Examples:
  sudo $(basename "$0") 10.10.10.10
  sudo $(basename "$0") -o ./scans --no-udp 10.10.10.10
  sudo $(basename "$0") -p 1-10000 -Pn 192.168.1.50
EOF
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warn "Scan interrupted or exited with error (status: $exit_code)."
    fi
    exit "$exit_code"
}

trap cleanup INT TERM

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "nmap-auto v${VERSION}"
                exit 0
                ;;
            -o|--output-dir)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "Option '$1' requires a directory path."
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -r|--rate)
                if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    log_error "Option '$1' requires a positive integer rate."
                    exit 1
                fi
                MIN_RATE="$2"
                shift 2
                ;;
            -T|--timing)
                if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-5]$ ]]; then
                    log_error "Option '$1' requires a timing template between 0 and 5."
                    exit 1
                fi
                TIMING="$2"
                shift 2
                ;;
            -p|--ports)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "Option '$1' requires a port specification (e.g., -p 1-1024 or -p-)."
                    exit 1
                fi
                PORT_RANGE="$2"
                shift 2
                ;;
            -Pn|--skip-ping)
                SKIP_PING=true
                shift
                ;;
            --no-udp)
                SKIP_UDP=true
                shift
                ;;
            --no-color)
                USE_COLOR=false
                setup_colors
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                usage >&2
                exit 1
                ;;
            *)
                if [[ -z "$TARGET" ]]; then
                    TARGET="$1"
                else
                    log_error "Unexpected argument: $1 (Target already set to '$TARGET')"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$TARGET" ]]; then
        log_error "Missing required target argument."
        echo "" >&2
        usage >&2
        exit 1
    fi
}

check_prerequisites() {
    if ! command -v nmap >/dev/null 2>&1; then
        log_error "'nmap' is not installed or not in PATH. Please install nmap and try again."
        exit 1
    fi

    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        log_error "Root privileges are required for SYN/UDP stealth scans. Please run with sudo."
        exit 1
    fi

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR" || {
            log_error "Failed to create output directory: $OUTPUT_DIR"
            exit 1
        }
    fi
}

sanitize_target_name() {
    # Replace characters not suitable for filenames (e.g. slashes)
    echo "$1" | tr '/:' '_-_'
}

run_tcp_port_scan() {
    local target="$1"
    local rate="$2"
    local timing="$3"
    local ports_arg="$4"
    local out_ports_var="$5"
    local pn_flag=()

    if [[ "$SKIP_PING" == true ]]; then
        pn_flag=("-Pn")
    fi

    log_info "Starting TCP Port Discovery on ${COLOR_MAGENTA}${target}${COLOR_RESET}.."
    echo ""

    local nmap_cmd=(
        nmap
        "-p${ports_arg}"
        "--min-rate=${rate}"
        "-T${timing}"
        "${pn_flag[@]}"
        "$target"
        "-v"
    )

    # Temporary file to capture discovered ports in real-time
    local temp_ports
    temp_ports=$(mktemp)

    # Run nmap and stream Discovered lines to console while capturing discovered ports
    # Nmap outputs: "Discovered open port <port>/tcp on <ip>"
    "${nmap_cmd[@]}" | while IFS= read -r line; do
        if [[ "$line" =~ Discovered[[:space:]]+open[[:space:]]+port[[:space:]]+([0-9]+)/ ]]; then
            local port="${BASH_REMATCH[1]}"
            echo "$port" >> "$temp_ports"
            log_info "Discovered open port: ${COLOR_MAGENTA}${port}/tcp${COLOR_RESET}"
        fi
    done

    local discovered_ports=""
    if [[ -f "$temp_ports" && -s "$temp_ports" ]]; then
        discovered_ports=$(sort -n -u "$temp_ports" | paste -sd, -)
        rm -f "$temp_ports"
    else
        rm -f "$temp_ports"
    fi

    printf -v "$out_ports_var" '%s' "$discovered_ports"
}

run_service_scan() {
    local target="$1"
    local ports="$2"
    local output_file="$3"
    local pn_flag=()

    if [[ "$SKIP_PING" == true ]]; then
        pn_flag=("-Pn")
    fi

    echo ""
    log_info "Initializing ${COLOR_MAGENTA}Service & Version Scan${COLOR_RESET}.."
    log_info "Scan results will be saved to ${COLOR_GREEN}${output_file}${COLOR_RESET} upon completion\n"

    local nmap_svc_cmd=(
        nmap
        "-p${ports}"
        "-sC"
        "-sV"
        "${pn_flag[@]}"
        "$target"
    )

    "${nmap_svc_cmd[@]}" | tee "$output_file"
    log_success "TCP Service Scan completed."
}

run_udp_scan() {
    local target="$1"
    local output_file="$2"

    echo ""
    log_info "${COLOR_MAGENTA}UDP Scan${COLOR_RESET} starting.. (top 100 ports)"
    log_info "Scan results will be saved to ${COLOR_GREEN}${output_file}${COLOR_RESET} upon completion\n"

    local nmap_udp_cmd=(
        nmap
        "-sU"
        "--top-ports" "100"
        "-Pn"
        "$target"
    )

    "${nmap_udp_cmd[@]}" | tee "$output_file"
    log_success "UDP Scan completed."
}

main() {
    setup_colors
    parse_arguments "$@"
    check_prerequisites
    print_banner

    local safe_target
    safe_target=$(sanitize_target_name "$TARGET")
    local tcp_result_file="${OUTPUT_DIR}/${safe_target}_scan_result_tcp.txt"
    local udp_result_file="${OUTPUT_DIR}/${safe_target}_scan_result_udp.txt"

    local open_ports=""
    run_tcp_port_scan "$TARGET" "$MIN_RATE" "$TIMING" "$PORT_RANGE" open_ports

    if [[ -z "$open_ports" ]]; then
        echo ""
        log_info "No open TCP ports discovered on ${COLOR_MAGENTA}${TARGET}${COLOR_RESET}."
        log_info "Scan finished."
        exit 0
    fi

    echo ""
    log_info "Open ports found: ${COLOR_MAGENTA}${open_ports}${COLOR_RESET}"

    run_service_scan "$TARGET" "$open_ports" "$tcp_result_file"

    if [[ "$SKIP_UDP" == false ]]; then
        run_udp_scan "$TARGET" "$udp_result_file"
    fi

    echo ""
    log_info "Happy Hacking! Bye."
}

main "$@"

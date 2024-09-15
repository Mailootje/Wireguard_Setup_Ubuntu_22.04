#!/bin/bash

# Global variables
SERVER_PORT=51820
INTERFACE="wg0"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get the public IPv4 address
get_public_ip() {
    curl -4 -s ifconfig.me
}

# Function to prompt number-based menu
ask_option() {
    echo "------------------------------------------------------------"
    echo "Select an option:"
    echo "1) Install and configure WireGuard"
    echo "2) Add users to an existing installation"
    echo "3) Remove users from an existing installation"
    echo "4) Show current users"
    echo "5) Generate QR code for an existing user"  # New option at position 5
    echo "6) Restart WireGuard service"
    echo "7) Check WireGuard status"
    echo "8) Check IP forwarding status"
    echo "9) Install additional tools"
    echo "10) Test if UDP port is open for WireGuard"
    echo "11) Fully delete WireGuard installation and configuration"
    echo "12) Exit"
    echo "------------------------------------------------------------"
    read -p "Enter your choice: " choice
    return $choice
}

# Function to add a user
add_user() {
    read -p "Enter username: " USERNAME
    CLIENT_CONF="/etc/wireguard/${USERNAME}.conf"
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
    CLIENT_IP="10.0.0.$((100 + $(wg show | grep allowed | wc -l)))"

    # Ensure the server public key is set
    SERVER_PUBLIC_KEY=$(wg show $INTERFACE public-key)

    # Ensure the public IP is set
    SERVER_PUBLIC_IP=$(get_public_ip)

    cat <<EOL > $CLIENT_CONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
EOL

    sudo wg set $INTERFACE peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32
    sudo wg-quick save $INTERFACE

    # Copy the configuration file to the original directory
    cp $CLIENT_CONF $ORIGINAL_DIR

    echo "------------------------------------------------------------"
    echo "Client configuration has been saved to $CLIENT_CONF and copied to $ORIGINAL_DIR:"
    cat $CLIENT_CONF
    echo "------------------------------------------------------------"

    # Generate a QR code for the configuration
    generate_qr_code $CLIENT_CONF
}

generate_qr_code() {
    local config_file=$1
    echo "Generating QR code for $config_file"
    qrencode -t ansiutf8 < "$config_file"
}

# Function to generate QR code from an existing user
generate_qr_for_existing_user() {
    echo "Existing users:"
    echo "------------------------------------------------------------"
    grep 'Address = ' /etc/wireguard/*.conf | awk -F'[:= ]+' '{print $1 " - " $NF}' | sed 's/\/etc\/wireguard\///;s/\.conf//'
    echo "------------------------------------------------------------"
    read -p "Enter the username for which you want to generate a QR code: " USERNAME
    CLIENT_CONF="/etc/wireguard/${USERNAME}.conf"

    if [ -f "$CLIENT_CONF" ]; then
        echo "Generating QR code for $USERNAME..."
        qrencode -t ansiutf8 < "$CLIENT_CONF"
    else
        echo "Error: Configuration file for user $USERNAME does not exist."
    fi
}

# Function to remove a user
remove_user() {
    echo "Existing users:"
    echo "------------------------------------------------------------"
    grep 'Address = ' /etc/wireguard/*.conf | awk -F'[:= ]+' '{print $1 " - " $NF}' | grep -v '10.0.0.1/24' | sed 's/\/etc\/wireguard\///;s/\.conf//'
    echo "------------------------------------------------------------"
    read -p "Enter username to remove: " USERNAME
    CLIENT_CONF="/etc/wireguard/${USERNAME}.conf"

    if [ -f $CLIENT_CONF ]; then
        CLIENT_PUBLIC_KEY=$(grep 'PublicKey' $CLIENT_CONF | awk '{print $3}')
        sudo wg set $INTERFACE peer $CLIENT_PUBLIC_KEY remove
        sudo wg-quick save $INTERFACE
        sudo rm -f $CLIENT_CONF
        echo "User $USERNAME has been removed."
    else
        echo "User $USERNAME does not exist."
    fi
}

# Function to show current users
show_users() {
    echo "Current users:"
    echo "------------------------------------------------------------"
    grep 'Address = ' /etc/wireguard/*.conf | awk -F'[:= ]+' '{print $1 " - " $NF}' | sed 's/\/etc\/wireguard\///;s/\.conf//'
    echo "------------------------------------------------------------"
}

# Function to restart WireGuard service
restart_wireguard() {
    sudo wg-quick down $INTERFACE
    sudo wg-quick up $INTERFACE
    echo "------------------------------------------------------------"
    echo "WireGuard service restarted."
    echo "------------------------------------------------------------"
}

# Function to check WireGuard status
check_status() {
    echo "------------------------------------------------------------"
    sudo wg show
    sudo systemctl status wg-quick@$INTERFACE
    echo "------------------------------------------------------------"
}

# Function to check IP forwarding status
check_ip_forwarding() {
    echo "------------------------------------------------------------"
    sysctl net.ipv4.ip_forward
    echo "------------------------------------------------------------"
}

# Function to install additional tools
install_tools() {
    echo "Select tools to install:"
    echo "1) speedtest-cli"
    echo "2) nload"
    echo "3) s-tui"
    echo "4) All of the above"
    read -p "Enter your choice (comma-separated for multiple): " tool_choice

    IFS=',' read -ra TOOLS <<< "$tool_choice"
    for tool in "${TOOLS[@]}"; do
        case $tool in
            1)
                sudo apt-get install -y speedtest-cli
                ;;
            2)
                sudo apt-get install -y nload
                ;;
            3)
                sudo apt-get install -y s-tui
                ;;
            4)
                sudo apt-get install -y speedtest-cli nload s-tui
                ;;
            *)
                echo "Invalid option: $tool"
                ;;
        esac
    done
    echo "------------------------------------------------------------"
    echo "Tool installation complete."
    echo "------------------------------------------------------------"
}

# Function to test if UDP port is open for WireGuard
test_udp_port() {
    echo "------------------------------------------------------------"
    SERVER_PUBLIC_IP=$(get_public_ip)
    echo "Testing if UDP port $SERVER_PORT is open for WireGuard on $SERVER_PUBLIC_IP..."
    nc -zvu $SERVER_PUBLIC_IP $SERVER_PORT
    if [ $? -eq 0 ]; then
        echo "UDP port $SERVER_PORT is open."
    else
        echo "UDP port $SERVER_PORT is closed or blocked."
    fi
    echo "------------------------------------------------------------"
}

# Function to fully delete WireGuard installation and configuration
delete_wireguard() {
    echo "WARNING: This will delete WireGuard installation and all configurations. This cannot be undone."
    read -p "Are you sure you want to proceed? Type 'YES' to confirm: " confirm
    if [ "$confirm" == "YES" ]; then
        echo "Stopping WireGuard service..."
        sudo wg-quick down $INTERFACE
        sudo systemctl disable wg-quick@$INTERFACE

        echo "Removing WireGuard configuration files..."
        sudo rm -rf /etc/wireguard

        echo "Removing WireGuard package..."
        sudo apt-get remove --purge -y wireguard

        echo "Removing iptables rules..."
        sudo iptables -D FORWARD -i $INTERFACE -j ACCEPT
        sudo iptables -D FORWARD -o $INTERFACE -j ACCEPT
        sudo iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
        sudo sh -c "iptables-save > /etc/iptables/rules.v4"

        echo "WireGuard has been completely removed."
    else
        echo "Deletion aborted."
    fi
    echo "------------------------------------------------------------"
}

# Function to install and configure WireGuard
install_wireguard() {
    # Update the system
    echo "Updating the system..."
    echo "------------------------------------------------------------"
    sudo apt-get update
    sudo apt-get upgrade -y

    # Install WireGuard if it's not already installed
    if ! command_exists wg; then
        echo "Installing WireGuard..."
        sudo apt-get install -y wireguard
    else
        echo "WireGuard is already installed."
    fi

    # Install qrencode for generating QR codes
    if ! command_exists qrencode; then
        echo "Installing qrencode for QR code generation..."
        sudo apt-get install -y qrencode
    else
        echo "qrencode is already installed."
    fi

    # Prompt user for the WireGuard server port
    read -p "Enter the port you want WireGuard to use (default is 51820): " custom_port
    SERVER_PORT=${custom_port:-51820}  # Use the provided port or default to 51820

    # Generate server keys
    echo "Generating server keys..."
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)

    # Server configuration
    SERVER_CONF="/etc/wireguard/wg0.conf"
    SERVER_IP="10.0.0.1"

    echo "Configuring WireGuard server on port $SERVER_PORT..."
    sudo mkdir -p /etc/wireguard
    sudo chmod 600 /etc/wireguard

    cat <<EOL | sudo tee $SERVER_CONF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_IP/24
ListenPort = $SERVER_PORT
SaveConfig = true
EOL

    # Enable IP forwarding
    echo "Enabling IP forwarding..."
    sudo sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

    # Add UFW rules if using UFW
    if command_exists ufw; then
        echo "Configuring UFW firewall..."
        sudo ufw allow $SERVER_PORT/udp
        sudo ufw allow OpenSSH
        sudo ufw enable
    fi

    # Add iptables rules for NAT
    echo "Configuring iptables firewall..."
    sudo iptables -A FORWARD -i $INTERFACE -j ACCEPT
    sudo iptables -A FORWARD -o $INTERFACE -j ACCEPT
    sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE

    # Save iptables rules
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    # Start WireGuard
    echo "Starting WireGuard..."
    sudo wg-quick up $INTERFACE
    sudo systemctl enable wg-quick@$INTERFACE

    # Get the public IP address of the server
    SERVER_PUBLIC_IP=$(get_public_ip)

    # Add initial users
    read -p "How many users do you want to add initially? " USER_COUNT
    for (( i=1; i<=USER_COUNT; i++ )); do
        add_user
    done
}

# Save the directory where the script was started
ORIGINAL_DIR=$(pwd)

# Main script logic
while true; do
    ask_option
    choice=$?
    case $choice in
        1)
            install_wireguard
            ;;
        2)
            read -p "How many users do you want to add? " USER_COUNT
            for (( i=1; i<=USER_COUNT; i++ )); do
                add_user
            done
            ;;
        3)
            read -p "How many users do you want to remove? " USER_COUNT
            for (( i=1; i<=USER_COUNT; i++ )); do
                remove_user
            done
            ;;
        4)
            show_users
            ;;
        5)  # New option to generate QR code for existing user
            generate_qr_for_existing_user
            ;;
        6)
            restart_wireguard
            ;;
        7)
            check_status
            ;;
        8)
            check_ip_forwarding
            ;;
        9)
            install_tools
            ;;
        10)
            test_udp_port
            ;;
        11)
            delete_wireguard
            ;;
        12)
            echo "Exiting."
            break
            ;;
        *)
            echo "Invalid option. Please select a valid option."
            ;;
    esac
done
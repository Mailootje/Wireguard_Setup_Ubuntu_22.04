#!/bin/bash

# Global variables
SERVER_PORT=51820
INTERFACE="wg0"
WEBHOOK_FILE="/etc/wireguard/discord_webhook.conf"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get the public IPv4 address
get_public_ip() {
    curl -4 -s ifconfig.me
}

# Function to read or ask for Discord webhook URL
get_discord_webhook() {
    # Check if the webhook file exists and has content
    if [ -f "$WEBHOOK_FILE" ] && [ -s "$WEBHOOK_FILE" ]; then
        # Source the file to read the variable
        source "$WEBHOOK_FILE"

        # Validate the URL format
        if ! [[ "$DISCORD_WEBHOOK" =~ ^https://discord(app)?.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$ ]]; then
            echo "The stored webhook URL is invalid: '$DISCORD_WEBHOOK'. Please provide a valid URL."
            read -p "Enter the Discord webhook URL: " DISCORD_WEBHOOK
            echo "DISCORD_WEBHOOK=\"$DISCORD_WEBHOOK\"" | sudo tee "$WEBHOOK_FILE" > /dev/null
        else
            return
        fi
    else
        # If the file doesn't exist or is empty, prompt the user for a custom URL
        echo "No valid Discord webhook URL found. Please provide a valid URL."
        read -p "Enter the Discord webhook URL: " DISCORD_WEBHOOK

        # Create the directory if it doesn't exist
        sudo mkdir -p $(dirname "$WEBHOOK_FILE")

        # Save the webhook URL as a variable in the file
        echo "DISCORD_WEBHOOK=\"$DISCORD_WEBHOOK\"" | sudo tee "$WEBHOOK_FILE" > /dev/null
        echo "Saved webhook URL: '$DISCORD_WEBHOOK'"
    fi
}

# Function to prompt DNS selection
select_dns() {
    echo "------------------------------------------------------------"
    echo "Select DNS for the client:"
    echo "1) Use Cloudflare DNS (1.1.1.1)"
    echo "2) Use Google DNS (8.8.8.8)"
    echo "3) Use custom DNS"
    echo "------------------------------------------------------------"
    read -p "Enter your choice: " dns_choice
    
    case $dns_choice in
        1)
            CLIENT_DNS="1.1.1.1"
            ;;
        2)
            CLIENT_DNS="8.8.8.8"
            ;;
        3)
            read -p "Enter custom DNS: " CLIENT_DNS
            ;;
        *)
            echo "Invalid option. Defaulting to Google DNS (8.8.8.8)."
            CLIENT_DNS="8.8.8.8"
            ;;
    esac
}

# Function to prompt number-based menu
ask_option() {
    echo "------------------------------------------------------------"
    echo "Select an option:"
    echo "1) Install and configure WireGuard"
    echo "2) Add users to an existing installation"
    echo "3) Remove users from an existing installation"
    echo "4) Show current users"
    echo "5) Generate QR code for an existing user"
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

# Function to add a single user (used by both initial install and add user)
add_single_user() {
    read -p "Enter username: " USERNAME
    CLIENT_CONF="/etc/wireguard/${USERNAME}.conf"
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
    CLIENT_IP="10.0.0.$((100 + $(wg show | grep allowed | wc -l)))"
    TIMESTAMP=$(date)

    # Ensure the server public key is set
    SERVER_PUBLIC_KEY=$(wg show $INTERFACE public-key)

    # Ensure the public IP is set
    SERVER_PUBLIC_IP=$(get_public_ip)

    # Prompt DNS selection
    select_dns

    cat <<EOL > $CLIENT_CONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = $CLIENT_DNS

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

    # Send Discord notification
    message="New user added: $USERNAME\nTimestamp: $TIMESTAMP\nConfiguration:\n$(cat $CLIENT_CONF)"
    send_discord_notification_with_qr "$message"
}

# Function to add users (for initial install)
add_users() {

    # Ensure Discord webhook is fetched or saved
    get_discord_webhook
    read -p "How many users do you want to add? " USER_COUNT
    for (( i=1; i<=USER_COUNT; i++ )); do
        add_single_user
    done
}

add_users_first_installation() {

    read -p "How many users do you want to add? " USER_COUNT
    for (( i=1; i<=USER_COUNT; i++ )); do
        add_single_user
    done
}

generate_qr_code() {
    local config_file=$1
    local qr_image="/tmp/${USERNAME}_qr.png"

    echo "Generating QR code for $config_file"
    
    # Generate QR code image in PNG format
    qrencode -o "$qr_image" < "$config_file"

    # Send QR code image and configuration to Discord
    message="New user added: $USERNAME\nTimestamp: $TIMESTAMP\n\nConfiguration:\n$(cat $config_file)"
    send_discord_notification_with_qr "$message" "$qr_image" "$USERNAME"
}

# Function to send a notification with a QR code image to Discord
send_discord_notification_with_qr() {
    local message=$1
    local qr_image=$2
    local username=$3

    # Ensure that the DISCORD_WEBHOOK variable is set
    if [ -z "$DISCORD_WEBHOOK" ]; then
        echo "Error: Discord webhook URL is not set. Cannot send notification."
        return 1
    fi

    # Send the QR code and message to Discord
    echo "Sending message and QR code for $username to Discord..."

    # Escape the message for JSON formatting
    escaped_message=$(echo "$message" | jq -Rs .)

    # Use curl to send both the message and QR code as a multipart form data request
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -F "file1=@$qr_image" \
        -F "payload_json={\"content\": $escaped_message}" \
        "$DISCORD_WEBHOOK")

    # Check the response status code
    if [ "$response" -ne 204 ]; then
        echo "Error: Failed to send QR code to Discord (HTTP status: $response)."
        return 1
    fi

    echo "QR code and message sent successfully to Discord."
    return 0
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

    # Ensure Discord webhook is fetched or saved
    get_discord_webhook

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

    # Add initial users
    add_users_first_installation  # Call the function to add users
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
            add_users  # Reuse the same user-adding function
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
            echo "Good bye!"
            break
            ;;
        *)
            echo "Invalid option. Please select a valid option."
            ;;
    esac
done

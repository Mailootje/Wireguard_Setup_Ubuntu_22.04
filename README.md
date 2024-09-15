---

# WireGuard Configurator

This is a comprehensive bash script for managing a WireGuard VPN server. The script allows you to install WireGuard, configure the server, manage users, and generate QR codes for easy client configuration.

## Features

- Install and configure WireGuard VPN server.
- Add, remove, and list users.
- Automatically generate client configuration files.
- Generate QR codes for easy import into WireGuard clients.
- Check server status and manage the WireGuard service.
- Install additional useful tools such as `speedtest-cli`, `nload`, and `s-tui`.
- Test if UDP port is open for WireGuard.
- Fully uninstall WireGuard and its configurations.

## Quick Start: One-Line Installation

You can quickly set up WireGuard on your Ubuntu 22.04 server by running the following command:

### Using `curl`:

```bash
curl -O https://raw.githubusercontent.com/Mailootje/Wireguard_Setup_Ubuntu_22.04/main/wireguard.sh && chmod +x wireguard.sh && ./wireguard.sh
```

### Using `wget`:

```bash
wget https://raw.githubusercontent.com/Mailootje/Wireguard_Setup_Ubuntu_22.04/main/wireguard.sh && chmod +x wireguard.sh && ./wireguard.sh
```

This command will download the script, make it executable, and start the setup process.

## Prerequisites

- Linux distribution (Ubuntu 22.04 recommended)
- Root or sudo access

### Required Packages

The script will automatically install the following packages if they are not already installed:

- **WireGuard**
- **curl**
- **qrencode**

## Installation and Usage

To install and run the script manually:

1. Clone this repository:

    ```bash
    git clone https://github.com/Mailootje/Wireguard_Setup_Ubuntu_22.04.git
    cd Wireguard_Setup_Ubuntu_22.04
    ```

2. Make the script executable:

    ```bash
    chmod +x wireguard.sh
    ```

3. Run the script:

    ```bash
    ./wireguard.sh
    ```

You will be prompted with a menu of options:

```
------------------------------------------------------------
Select an option:
1) Install and configure WireGuard
2) Add users to an existing installation
3) Remove users from an existing installation
4) Show current users
5) Restart WireGuard service
6) Check WireGuard status
7) Check IP forwarding status
8) Install additional tools
9) Test if UDP port is open for WireGuard
10) Fully delete WireGuard installation and configuration
11) Exit
------------------------------------------------------------
```

### Key Functionalities

- **Install and Configure WireGuard**: This option installs WireGuard, generates server keys, configures the server, enables IP forwarding, and allows you to add initial users. The script also installs `qrencode` for generating QR codes.
  
- **Add Users**: Adds users to the WireGuard server, generates a client configuration, and displays a QR code in the terminal for easy import into the WireGuard mobile or desktop app.

- **Remove Users**: Removes the user’s configuration and peer entry from the WireGuard server.

- **Show Current Users**: Lists all users currently configured on the WireGuard server.

- **Restart WireGuard Service**: Restarts the WireGuard service to apply new configuration changes.

- **Check WireGuard Status**: Displays the current status of the WireGuard server and active connections.

- **Check IP Forwarding Status**: Ensures that IP forwarding is enabled, which is required for routing traffic through the VPN.

- **Install Additional Tools**: Optionally installs useful tools like:
    - `speedtest-cli` (for testing internet speed)
    - `nload` (for monitoring network traffic)
    - `s-tui` (for monitoring system performance)

- **Test UDP Port**: Verifies if the UDP port used by WireGuard is open and accessible from outside.

- **Fully Delete WireGuard**: Completely removes WireGuard and all associated configurations.

## Adding Users

When you add a user, the script generates a configuration file and displays a QR code for easy scanning and import into the WireGuard app.

### Example Client Configuration:

```
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.0.0.X/24
DNS = 8.8.8.8

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = SERVER_PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
```

The QR code will look something like this:

```
------------------------------------------------------------
Client configuration has been saved to /etc/wireguard/username.conf:
[...]
------------------------------------------------------------
Generating QR code for /etc/wireguard/username.conf:
█████████████████████████████████
█████████████████████████████████
████ ▄▄▄▄▄ █ ██▀▀ ▄▄▄█ ▄▄▄▄▄ ████
████ █   █ █  ▀█ ▀▄▄▀█ █   █ ████
████ █▄▄▄█ █▀  █▄█▄▄ █ █▄▄▄█ ████
████▄▄▄▄▄▄▄█▄█ ▀▄█▄█▄█▄▄▄▄▄▄▄████
████ ▄█▀  ▄█▀█▄█▄▀▀▀▀▀█▄▀ ▄ ▄████
█████▀█ █▀▄   ▄█▀▄▀▄██▀ ▄▄ ▀█████
████▀▀█ ▄▀▄▀▀█▀▄▀█▀ ▀ ▄█▀▄▄ ▄████
██████ ▀▄ ▄▀▀██ ▄▄ ▄██▀  ▄ ▀█████
████▄▄█▄█▄▄█▀▄ █▄█▀▄ ▄▄▄ ▄▄██████
████ ▄▄▄▄▄ █▀▄▀█▀█ █ █▄█ ▀▀▀▀████
████ █   █ █▄▀▄▄▀▄ ▀ ▄  ▄▄   ████
████ █▄▄▄█ █▀▄█ ▄ ▄▀▄▄ ▀▀ ▀ █████
████▄▄▄▄▄▄▄█▄███▄▄█▄██████▄▄▄████
█████████████████████████████████
█████████████████████████████████
```

## Uninstallation

To completely remove WireGuard and its configuration files, select option `10` from the main menu. **Warning**: This action cannot be undone.

## Contributing

Contributions are welcome! Feel free to submit issues, fork this repository, and send pull requests with improvements.
---
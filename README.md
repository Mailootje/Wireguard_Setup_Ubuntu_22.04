Here’s a `README.md` template for your WireGuard configurator project that you can use on GitHub:

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

## Prerequisites

Before using this script, ensure that you are running a Linux distribution that supports `apt`, such as Ubuntu or Debian, as this script uses `apt` for package management.

### Required Packages

- **WireGuard**
- **curl**
- **qrencode** (automatically installed by the script)

## Installation

Clone this repository and navigate into the project directory:

```bash
git clone https://github.com/yourusername/wireguard-configurator.git
cd wireguard-configurator
```

Make the script executable:

```bash
chmod +x wireguard-configurator.sh
```

## Usage

Run the script with:

```bash
./wireguard-configurator.sh
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

1. **Install and Configure WireGuard**  
   This option installs WireGuard, generates server keys, configures the server, enables IP forwarding, and allows you to add initial users. The script automatically installs `qrencode` for QR code generation.
   
2. **Add Users**  
   When adding users, the script will generate a client configuration file and a corresponding QR code that can be scanned by the WireGuard mobile or desktop app.

3. **Remove Users**  
   This option removes the user's configuration and their corresponding peer entry from the server.

4. **Show Current Users**  
   Lists all users that are currently configured on the WireGuard server.

5. **Restart WireGuard Service**  
   Restarts the WireGuard service to apply any new configuration changes.

6. **Check WireGuard Status**  
   Shows the current WireGuard server status and active connections.

7. **Check IP Forwarding Status**  
   Verifies if IP forwarding is enabled on the server, which is required for proper routing.

8. **Install Additional Tools**  
   Optionally installs useful tools like:
   - `speedtest-cli` (for testing internet speed)
   - `nload` (for monitoring network traffic)
   - `s-tui` (for monitoring system performance)

9. **Test UDP Port**  
   Tests if the specified UDP port for WireGuard is open and accessible from outside.

10. **Fully Delete WireGuard**  
    Completely removes WireGuard and all associated configurations, including iptables rules.

## Adding Users

When you add a user, the script will automatically generate a configuration file and print a QR code in the terminal for easy import into the WireGuard app.

### Example User Configuration:

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

After adding a user, the QR code is displayed like this:

```
------------------------------------------------------------
Client configuration has been saved to /etc/wireguard/username.conf:
[...]
------------------------------------------------------------
Generating QR code for /etc/wireguard/username.conf:
████████████████████████████████████████████████████████████████
████ ▄▄▄▄▄ ██▀██▄█▀▀▀▄██▀▄█▀ ▀▄█ ▄▀▄▄ ▀▀▄█▄▀▀█ ▄▄▄▄▄ ██▄ ▄██ ████
████ █   █ █▀█ ▀▄▀▀██▀▄▀██▄▀█▄▀███▀ ▄█▀▄▄▀ ▀▄█▄▀ ▀▄▀▄█ █   ████
████ █▄▄▄█ ██▄█▄█▄▄▄▄ ▀▄█▄█▀██▀ ▄██▀▄▀▀█▀▀▄█▄▀██▄▄▄▄█ █▄▄▄█ ████
████▄▄▄▄▄▄▄█▄▀ ▀▄▀▄█▄▀▄▀ ▀▄▄▄▀▄█▄▀▄▀▄█▄█▄▀ █▄▀▄▀▄▀▄▀▄▄▄▄▄▄▄████
```

## Uninstallation

To uninstall WireGuard and remove all configurations, select the option `10` from the main menu. **Note**: This action cannot be undone.

## Contributing

Feel free to submit issues or pull requests to improve this project. All contributions are welcome!

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
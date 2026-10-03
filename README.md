# Raspberry Pi Omada Controller

Automated Raspberry Pi deployment for the TP-Link Omada Software Controller.

Target:

- Raspberry Pi 4B
- Raspberry Pi OS Lite 64-bit
- Docker
- Omada Controller 5.15

## Fresh Installation

### 1. Flash Raspberry Pi OS

Using Raspberry Pi Imager:

- Raspberry Pi OS Lite (64-bit)
- Enable SSH
- Create your user
- Set hostname
- Configure timezone
- Connect the Pi using Ethernet

### 2. SSH into the Pi

For example:

    ssh pi@omada-pi.local

Or use the IP assigned by DHCP.

### 3. Run the bootstrap script

    curl -fsSL https://raw.githubusercontent.com/brandonrallen/rpi-omada/main/bootstrap.sh | sudo bash

The script will:

1. Verify the OS is 64-bit
2. Update Raspberry Pi OS
3. Install Git
4. Install Docker
5. Configure the hostname
6. Clone this repository
7. Validate Docker Compose
8. Pull Omada Controller 5.15
9. Start Omada
10. Display the Omada Controller URL

## After Installation

The controller will be available at:

    https://PI-IP:8043

Example:

    https://192.168.10.7:8043

Your browser will initially warn about the certificate.

Continue to the Omada setup page.

## DHCP Reservation

The Pi uses DHCP.

After installation, create a DHCP reservation in the router using the Pi's MAC address.

This gives the Omada Controller a permanent IP without configuring a static IP inside Raspberry Pi OS.

## Useful Commands

Go to the installation directory:

    cd /opt/rpi-omada

Check the container:

    docker compose ps

View logs:

    docker compose logs -f

Restart:

    docker compose restart

Stop:

    docker compose down

Start:

    docker compose up -d

Update the container:

    docker compose pull
    docker compose up -d

## Persistent Data

Omada data is stored in:

    /opt/rpi-omada/data

Logs are stored in:

    /opt/rpi-omada/logs

Recreating the Docker container does not remove the Omada configuration.

## Rebuilding the Pi

For a completely fresh Raspberry Pi:

1. Flash Raspberry Pi OS Lite 64-bit
2. Enable SSH
3. Boot the Pi
4. SSH into the Pi
5. Run:

    curl -fsSL https://raw.githubusercontent.com/brandonrallen/rpi-omada/main/bootstrap.sh | sudo bash

The Pi will be rebuilt automatically.

## Repository Structure

    rpi-omada/
    ├── bootstrap.sh
    ├── compose.yml
    └── README.md
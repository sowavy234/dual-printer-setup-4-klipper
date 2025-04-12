#!/bin/bash

set -e

echo "=== Klipper Dual Printer Setup: Megatron (Ender 3 S1 Pro) + Starscream (Kobra 2 Neo) ==="

# Update system
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y git python3-pip python3-dev python3-venv build-essential \
  libffi-dev libncurses-dev libusb-1.0-0-dev libjpeg-dev \
  libSDL1.2-dev avrdude gcc-avr binutils-avr avr-libc dfu-util unzip cmake

# Directories
cd ~
mkdir -p klipper_data/printer_starscream_data
mkdir -p klipper_data/printer_megatron_data

# Backup existing configs
echo "[+] Backing up any existing configs..."
mkdir -p ~/printer_cfg_backups
cp ~/printer.cfg ~/printer_cfg_backups/printer_megatron.cfg 2>/dev/null || true
cp ~/printer_starscream.cfg ~/printer_cfg_backups/printer_starscream.cfg 2>/dev/null || true

# Clone extra macros/tools
echo "[+] Cloning macro/plugin repositories..."
cd ~
git clone https://github.com/mmone/OctoprintKlipperPlugin.git || true
git clone https://github.com/Desuuuu/klipper-macros.git || true
git clone https://github.com/Frix-x/klippain-shaketune.git || true
git clone https://github.com/Tombraider2006/klipperFB6.git || true
git clone https://github.com/protoloft/klipper_z_calibration.git || true

# Symlink useful macros into configs later
mkdir -p ~/klipper_data/macros
cp klipper-macros/*.cfg ~/klipper_data/macros/
cp klipper_z_calibration/z_calibration.cfg ~/klipper_data/macros/

# Setup Moonraker2 + Klipper2 service
echo "[+] Setting up second Moonraker/Klipper instance for Starscream..."

sudo cp /etc/systemd/system/klipper.service /etc/systemd/system/klipper2.service
sudo cp /etc/systemd/system/moonraker.service /etc/systemd/system/moonraker2.service

sudo sed -i 's/\/home\/pi\/klipper\/klippy\.venv/\/home\/pi\/klipper\/klippy.venv/g' /etc/systemd/system/klipper2.service
sudo sed -i 's/ExecStart=.*/ExecStart=\/home\/pi\/klipper\/klippy-env\/bin\/python3 \/home\/pi\/klipper\/klippy\/klippy.py \/home\/pi\/klipper_data\/printer_starscream_data\/printer.cfg/' /etc/systemd/system/klipper2.service

sudo sed -i 's/ExecStart=.*/ExecStart=\/home\/pi\/moonraker-env\/bin\/python3 \/home\/pi\/moonraker\/moonraker.py -c \/home\/pi\/klipper_data\/printer_starscream_data\/moonraker.conf/' /etc/systemd/system/moonraker2.service

# Reload services
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable klipper2.service moonraker2.service
sudo systemctl restart klipper2.service moonraker2.service

# Fluidd merged config
echo "[+] Installing Fluidd and configuring both printers in one dashboard..."
cd ~
mkdir -p ~/fluidd
wget -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip
unzip -o fluidd.zip -d ~/fluidd

# Symlink both printer configs to fluidd access
ln -sf ~/klipper_data/printer_megatron_data/printer.cfg ~/fluidd/printer_megatron.cfg
ln -sf ~/klipper_data/printer_starscream_data/printer.cfg ~/fluidd/printer_starscream.cfg

# Set up KlipperScreen
echo "[+] Setting up KlipperScreen..."
sudo apt install -y xinit xserver-xorg x11-xserver-utils x11-utils xinput
cd ~
git clone https://github.com/jordanruthe/KlipperScreen.git
cd KlipperScreen
./scripts/KlipperScreen-install.sh

# Add KlipperScreen buttons
mkdir -p ~/.KlipperScreen/config
cat <<EOF > ~/.KlipperScreen/config/buttons.json
{
  "macros": [
    {
      "name": "Smart Z Offset",
      "gcode": "Z_CALIBRATE"
    },
    {
      "name": "Input Shaper",
      "gcode": "TUNING_TOWER COMMAND=SET_VELOCITY_LIMIT PARAMETER=ACCEL START=500 STEP_DELTA=100 STEP_HEIGHT=0.1 COUNT=10"
    }
  ]
}
EOF

# Finish
echo "====================================================="
echo "✅ All done. Now flash your printers manually:"
echo "1. Megatron (Ender 3 S1 Pro) via USB"
echo "2. Starscream (Kobra 2 Neo) via SD card"
echo
echo "Then reboot and enjoy dual printer Fluidd dashboard!"
echo "====================================================="

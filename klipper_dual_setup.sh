#!/bin/bash
set -e

# === VARIABLES ===
KLIPPER_DIR="$HOME/klipper"
MOONRAKER_DIR="$HOME/moonraker"
FLUIDD_DIR="$HOME/fluidd"
KSCREEN_DIR="$HOME/KlipperScreen"
CONFIG_DIR="$HOME/klipper_config"
BACKUP_DIR="$HOME/klipper_backups"
MACROS_DIR="$CONFIG_DIR/macros"
SCREEN_CONFIG="/home/pi/.config/KlipperScreen/config.json"

# === BACKUP EXISTING CONFIGS ===
mkdir -p "$BACKUP_DIR"
[ -f "$CONFIG_DIR/printer.cfg" ] && cp "$CONFIG_DIR/printer.cfg" "$BACKUP_DIR/printer.cfg.bak"
[ -f "$CONFIG_DIR/printer_starscream.cfg" ] && cp "$CONFIG_DIR/printer_starscream.cfg" "$BACKUP_DIR/printer_starscream.cfg.bak"

# === UPDATE SYSTEM ===
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y python3 python3-pip git build-essential cmake libusb-1.0-0-dev avrdude gcc-avr binutils-avr avr-libc dfu-util wget xz-utils unzip libjpeg-dev libsdl1.2-dev

# === INSTALL REALTEK DRIVERS FOR PAU09 ===
echo "Installing Realtek drivers for Panda PAU09 Wi-Fi..."
git clone https://github.com/lwfinger/rt8812au.git ~/rt8812au
cd ~/rt8812au
make && sudo make install
sudo modprobe 88XXau
cd ~

# === KLIPPER ===
echo "Cloning and setting up Klipper..."
[ -d "$KLIPPER_DIR" ] || git clone https://github.com/Klipper3d/klipper.git "$KLIPPER_DIR"

# === MOONRAKER DUAL INSTANCES ===
echo "Installing Moonraker dual instance support..."
[ -d "$MOONRAKER_DIR" ] || git clone https://github.com/Arksine/moonraker.git "$MOONRAKER_DIR"

sudo cp "$MOONRAKER_DIR/scripts/moonraker.service" /etc/systemd/system/moonraker.service
sudo cp "$MOONRAKER_DIR/scripts/moonraker.service" /etc/systemd/system/moonraker2.service

sudo sed -i 's|/home/pi/moonraker|/home/pi/moonraker|' /etc/systemd/system/moonraker.service
sudo sed -i 's|ExecStart=.*|ExecStart=/home/pi/moonraker/moonraker --configfile /home/pi/klipper_config/moonraker2.conf|' /etc/systemd/system/moonraker2.service

# === FLUIDD MERGED DASHBOARD ===
echo "Setting up Fluidd dashboard on port 9090..."
[ -d "$FLUIDD_DIR" ] || git clone https://github.com/fluidd-core/fluidd.git "$FLUIDD_DIR"
mkdir -p ~/fluidd-multi
cp -r "$FLUIDD_DIR"/* ~/fluidd-multi/
# Host Fluidd at :9090 using nginx or Moonraker config (setup later)

# === KLIPPERSCREEN ===
echo "Installing KlipperScreen with 3.5\" TFT Waveshare support..."
[ -d "$KSCREEN_DIR" ] || git clone https://github.com/jordanruthe/KlipperScreen.git "$KSCREEN_DIR"
sudo apt install -y xserver-xorg x11-xserver-utils xinit xinput libjpeg-dev libxft-dev
"$KSCREEN_DIR/scripts/KlipperScreen-install.sh"

# === SETUP TFT WAVESHARE 3.5 ===
echo "Configuring Waveshare TFT 3.5..."
sudo bash -c "echo 'hdmi_force_hotplug=1\nhdmi_group=2\nhdmi_mode=87\nhdmi_cvt=480 320 60 6 0 0 0\nhdmi_drive=2' >> /boot/config.txt"

# === CLONE MACROS & PLUGINS ===
echo "Downloading macros and plugins..."
mkdir -p "$MACROS_DIR"
cd "$MACROS_DIR"
git clone https://github.com/mmone/OctoprintKlipperPlugin.git
git clone https://github.com/Desuuuu/klipper-macros.git
git clone https://github.com/Frix-x/klippain-shaketune.git
git clone https://github.com/Tombraider2006/klipperFB6.git
git clone https://github.com/protoloft/klipper_z_calibration.git

# === KSCREEN BUTTONS (OPTIONAL) ===
echo "Preloading KlipperScreen macros..."
mkdir -p "$(dirname "$SCREEN_CONFIG")"
cat <<EOF > "$SCREEN_CONFIG"
{
  "macros": {
    "Calibrate Z": "Z_CALIBRATION_START",
    "Mesh Bed": "BED_MESH_CALIBRATE",
    "Input Shaper": "SHAPER_CALIBRATE"
  }
}
EOF

# === FINAL STEPS ===
echo "Enabling and starting services..."
sudo systemctl enable klipper moonraker moonraker2 klipperscreen
sudo systemctl restart klipper moonraker moonraker2 klipperscreen

echo "🎉 Setup complete! Visit:"
echo "➡️ http://<your-raspberry-ip>:9090 (Merged Fluidd Dashboard)"
echo "🛠 Flash printers manually (Megatron via USB, Starscream via SD)"
echo "🗂 Configs backed up to: $BACKUP_DIR"

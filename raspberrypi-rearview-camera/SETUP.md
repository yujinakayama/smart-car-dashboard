# Setting up Raspberry Pi for Car Rearview Camera

This guide describes the steps to set up your Raspberry Pi for car rearview camera with the following characteristics:

* Faster boot time (about 16 seconds with Raspberry Pi 3B+)
* Less power consumption
* Support for sudden power down

## Requirements

* Raspberry Pi with Ethernet port (3B+)
* Raspberry Pi Camera Module V2
    * Optinal: [Arducam 8MP Wide Angle Drop-in Replacement for Raspberry Pi Camera Module V2, IMX219 Sensor with M12 Mount Lens, 175 Degrees FoV Diagonal](https://www.amazon.com/gp/product/B07V322VCX)) for smaller module and wide angle lens

## References

* [Himesh's Blog: Fast boot with Raspberry Pi](http://himeshp.blogspot.com/2018/08/fast-boot-with-raspberry-pi.html)
* [Boot options in config.txt - Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/configuration/config-txt/boot.md)
* [How to save power on your Raspberry Pi • Pi Supply Maker Zone](https://learn.pi-supply.com/make/how-to-save-power-on-your-raspberry-pi/)

## Steps

### Install Raspberry Pi OS (previously called Raspbian) with Mac

Download [Raspberry Pi OS (32-bit) Lite](https://www.raspberrypi.org/downloads/raspberry-pi-os/) (Version: August 2020).

Burn the image into a SD card with balena Etcher.

Re-insert the SD card into the Mac and run `touch /Volumes/boot/ssh` to enable SSH.

Create file `/Volumes/boot/wpa_supplicant.conf` with the following content:

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=JP

network={
    ssid="MY_SSID"
    psk="MY_PASSWORD"
    priority=100
}
```

### Log in to Raspberry Pi with SSH

Insert the SD card into the Raspberry Pi.

Connect the Mac to the Wi-Fi and turn on the Raspberry Pi.

Run `ssh pi@raspberrypi.local` on the Mac and enter password `raspberry`.

### Update OS

* Update packages:

```
$ sudo apt update
$ sudo apt upgrade
$ sudo reboot
```

### Enable camera

Enable camera with `sudo raspi-config` -> `Interfacing Options` -> `Camera`.
This will modify `/boot/config.txt`.

### Remove unneccessary services for faster boot

Analyze time-consuming services:

```
$ systemd-analyze blame
          6.862s hciuart.service
          2.464s dev-mmcblk0p2.device
          2.273s ifupdown-pre.service
           646ms systemd-fsck@dev-disk-by\x2dpartuuid-90a92c92\x2d01.service
           590ms keyboard-setup.service
           498ms networking.service
           436ms raspi-config.service
           417ms systemd-udev-trigger.service
           415ms systemd-timesyncd.service
           366ms dphys-swapfile.service
           326ms wpa_supplicant.service
           303ms systemd-logind.service
           295ms avahi-daemon.service
           293ms systemd-journald.service
           281ms user@1000.service
           265ms systemd-fsck-root.service
           229ms rsyslog.service
           218ms ssh.service
           203ms fake-hwclock.service
           189ms run-rpc_pipefs.mount
           188ms kmod-static-nodes.service
           180ms rpi-eeprom-update.service
           177ms rng-tools.service
           176ms systemd-modules-load.service
           174ms systemd-remount-fs.service
           169ms dev-mqueue.mount
           164ms systemd-udevd.service
           156ms triggerhappy.service
           148ms bluetooth.service
           145ms systemd-tmpfiles-setup.service
           138ms systemd-update-utmp.service
           123ms systemd-tmpfiles-clean.service
           112ms systemd-journal-flush.service
           111ms sys-kernel-debug.mount
           105ms systemd-sysctl.service
           102ms alsa-restore.service
            80ms systemd-sysusers.service
            79ms systemd-random-seed.service
            74ms systemd-tmpfiles-setup-dev.service
            71ms boot.mount
            66ms sys-kernel-config.mount
            62ms systemd-update-utmp-runlevel.service
            60ms systemd-rfkill.service
            39ms user-runtime-dir@1000.service
            38ms console-setup.service
            33ms systemd-user-sessions.service
            26ms nfs-config.service
            14ms rc-local.service
```

Disable the following services with `systemctl disable`:

```
hciuart.service
keyboard-setup.service
raspi-config.service
systemd-timesyncd.service
dphys-swapfile.service
rpi-eeprom-update.service
triggerhappy.service
bluetooth.service
alsa-restore.service
triggerhappy.socket
```

### Configure boot options for faster boot

Append the following content to `/boot/config.txt`:

```
# Fast Boot

# Disable the rainbow splash screen
disable_splash=1

# Disable bluetooth
dtoverlay=pi3-disable-bt

# Disable Wifi
#dtoverlay=pi3-disable-wifi

# Set the bootloader delay to 0 seconds. The default is 1s if not specified.
boot_delay=0
```

Insert `quiet` before `rootwait` in `/boot/cmdline.txt`.

Remove `/etc/profile.d/wifi-check.sh` to suppress error messages `rfkill: cannot open /dev/rfkill: Permission denied` on SSH login:

[rfkill not working - Raspberry Pi Forums](https://www.raspberrypi.org/forums/viewtopic.php?t=274816)

```
$ sudo rm /etc/profile.d/wifi-check.sh
```

### Turn off HDMI output to save power

https://lab.stefanoperna.it/tutorial/raspberry-pi/switch-onoff-the-hdmi-port-in-raspberry-pi-3/

Add the following lines to `/etc/rc.local` before `exit 0`:

```
# Turn off HDMI output to save power
/opt/vc/bin/tvservice --off
```

### Create admin user and remove default user `pi`:

Create a user:

```
$ sudo useradd --create-home --groups sudo --user-group MY_USER
$ sudo passwd MY_USER
New password:
Retype new password:
passwd: password updated successfully
```

Remove the default user `pi`:

```
pi@raspberrypi:~ $ logout
$ ssh MY_USER@192.168.200.1
MYUSER@raspberrypi:~ $ sudo userdel --remove pi
```

### Make `raspivid` server run on boot

Create an executable `raspivid-server`:

```
$ sudo nano /opt/bin/raspivid-server
#!/bin/sh

# https://www.raspberrypi.org/documentation/raspbian/applications/camera.md

raspivid \
--nopreview \
--listen --output tcp://0.0.0.0:5001 \
--flush --timeout 0 \
--width 1440 --height 1080 --framerate 40 \
--profile high --level 4.2 \
--awb off --awbgains 1.4,1.6 \
--exposure auto --metering average --drc high --flicker auto \
--ev -10 --brightness 55 --saturation 12 --sharpness 100 \
--imxfx denoise \
--hflip \
#--verbose --settings
# TODO: Use --digitalgain more than 4 at night
$ sudo chmod 755 /opt/bin/raspivid-server
```

Create a user to run `raspivid-server`:

```
$ sudo useradd --groups video --user-group raspivid-server
```

Create systemd unit files:

```
$ sudo nano /etc/systemd/system/raspivid-server.service
[Unit]
Description=raspivid streaming server
After=network.target

[Service]
Type=simple
ExecStart=/opt/bin/raspivid-server
Restart=always
RestartSec=0
StartLimitInterval=10
StartLimitBurst=20
User=raspivid-server

[Install]
WantedBy=multi-user.target
$ sudo nano /etc/systemd/system/raspivid-server-restarter.service
[Unit]
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart raspivid-server.service
StartLimitInterval=10
StartLimitBurst=20

[Install]
WantedBy=multi-user.target
$ sudo nano /etc/systemd/system/raspivid-server-restarter.path
[Path]
PathModified=/opt/bin/raspivid-server

[Install]
WantedBy=multi-user.target
```

Enable the services:

```
$ sudo systemctl enable raspivid-server.service
$ sudo systemctl enable raspivid-server-restarter.path
```

### Make `raspivid-adjuster-server` run on boot

Create a user to run `raspivid-adjuster-server`:

```
$ sudo useradd --user-group --create-home raspivid-adjuster-server
```

Install ruby:

https://github.com/rbenv/ruby-build/wiki#suggested-build-environment

```
$ sudo apt install git
$ sudo apt install autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev
$ sudo -u raspivid-adjuster-server -i
$ git clone https://github.com/rbenv/rbenv.git ~/.rbenv
$ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile
$ echo 'eval "$(rbenv init -)"' >> ~/.profile
$ exit
$ sudo -u raspivid-adjuster-server -i
$ mkdir -p "$(rbenv root)"/plugins
$ git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
$ rbenv install 2.7.2
$ rbenv global 2.7.2
```

Deploy `raspivid-adjuster-server`:

https://github.com/rbenv/rbenv/wiki/Deploying-with-rbenv#app-bundles-and-binstubs

```
$ sudo systemctl start systemd-timesyncd.service # Sync clock with ntp so that rubygems certificate validation won't fail
$ sudo -u raspivid-adjuster-server -i
$ git clone https://github.com/yujinakayama/ipad-car-integration
$ cd ipad-car-integration/raspberrypi-rearview-camera/raspivid-adjuster-server
$ bundle install --deployment --binstubs
```

Create systemd unit file:

```
$ sudo nano /etc/systemd/system/raspivid-adjuster-server.service
[Unit]
Description=raspivid adjuster server
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/raspivid-adjuster-server/ipad-car-integration/raspberrypi-rearview-camera/raspivid-adjuster-server
Environment=PATH=/home/raspivid-adjuster-server/.rbenv/shims:/home/raspivid-adjuster-server/.rbenv/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/home/raspivid-adjuster-server/ipad-car-integration/raspberrypi-rearview-camera/raspivid-adjuster-server/bin/rackup --host 0.0.0.0 --port 5002
Restart=always
User=raspivid-adjuster-server

[Install]
WantedBy=multi-user.target
```

Enable the service:

```
$ sudo systemctl enable raspivid-adjuster-server.service
```

Allow the server to rewrite `/opt/bin/raspivid-server`:

```
$ sudo chown raspivid-adjuster-server:raspivid-adjuster-server /opt/bin/raspivid-server
```

### Add scripts to enable/disable Wi-Fi

Basically we should disable Wi-Fi in usual operation for faster boot, but we may need to enable Wi-Fi to tweak configuration:

```
$ sudo mkdir /opt/bin
```

```
$ sudo nano /opt/bin/enable-wifi
sed --in-place --expression 's/^dtoverlay=pi3-disable-wifi/#dtoverlay=pi3-disable-wifi/' /boot/config.txt
systemctl enable wpa_supplicant.service
systemctl enable avahi-daemon.service
systemctl enable dhcpcd.service
echo "Reboot to apply the change."
$ sudo chmod 755 /opt/bin/enable-wifi
```

```
$ sudo nano /opt/bin/disable-wifi
sed --in-place --expression 's/^#dtoverlay=pi3-disable-wifi/dtoverlay=pi3-disable-wifi/' /boot/config.txt
systemctl disable wpa_supplicant.service
systemctl disable avahi-daemon.service
systemctl disable dhcpcd.service
echo "Reboot to apply the change."
$ sudo chmod 755 /opt/bin/disable-wifi
```

### Use static IP address for Ethernet and disable Wi-Fi for faster boot

[networking - disable dhcpcd.service for static ip? - Raspberry Pi Stack Exchange](https://raspberrypi.stackexchange.com/a/106914)

Set a static IP address:

```
$ sudo nano /etc/network/interfaces.d/eth0
# Don't specify `auth eth0` since it make boot time longer
# https://askubuntu.com/a/887458
allow-hotplug eth0
iface eth0 inet static
address 192.168.100.1
netmask 255.255.255.0
```

Connect the Mac and the Raspberry Pi with an Ethernet cable.

Reboot and confirm that you can log in with

```
$ ssh pi@192.168.100.1
```

Disable Wi-Fi:

```
$ sudo /opt/bin/disable-wifi
```

Reboot:

```
$ sudo reboot
```

### Make filesystem read-only for sudden power down

Make filesystem read-only with `sudo raspi-config` -> `Advanced Options` -> `Overlay FS`.

#!/bin/bash

echo 'Copying files...'
cp ./sleep_power.sh /usr/local/sbin/
chmod +x /usr/local/sbin/sleep_power.sh
cp ./sleep_power_suspend.service /etc/systemd/system
cp ./sleep_power_resume.service /etc/systemd/system

echo 'Enabling services...'
systemctl enable sleep_power_suspend
systemctl enable sleep_power_resume

echo 'Install complete.'
echo 'Sleep_power log is located at: /var/log/sleep_power.log'

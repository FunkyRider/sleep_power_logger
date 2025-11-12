#!/bin/bash

echo 'Disabling services...'
systemctl disable sleep_power_suspend
systemctl disable sleep_power_resume

echo 'Deleting files...'
rm /etc/systemd/system/sleep_power_suspend.service
rm /etc/systemd/system/sleep_power_resume.service
rm //usr/local/sbin/sleep_power.sh

echo 'Uninstall complete.'

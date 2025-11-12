
# Sleep Power Logger
A simple Linux shell script to log laptop sleep / resume time, battery energy and calculate power consumption.

### Usage
The package consist a script to record machine suspend / resume point in time, as well as battery energy value. At resume, it will calculate the total time spent in sleep and energy used. I will also calculate average power in sleep mode. This is very useful in help diagnosing sleep problem, especially the s0ix (modern standby) power consumption.

### Installation
run install.sh as super user to install the script and systemd services.
run uninstall.sh as super user to remove the script and systemd services.
After installation, just use laptop as normal. After each suspend / resume it will write log entries to /var/log/sleep_time.log. It is recommended to let the laptop sleep for at least 1 hour to get more accurate reading.

### Example output
2025-11-12 01:28:06 suspend 35.560 Wh  
2025-11-12 07:44:43 resume 33.840 Wh  
consumed: 1.720 Wh dt: 06:16:37 (6.28 h) avg: 0.274 W  
2025-11-12 07:45:16 suspend 33.800 Wh  
2025-11-12 11:31:38 resume 32.770 Wh  
consumed: 1.030 Wh dt: 03:46:22 (3.77 h) avg: 0.273 W  
2025-11-12 11:35:20 suspend 32.350 Wh  
2025-11-12 11:45:16 resume 32.260 Wh  
consumed: 0.090 Wh dt: 00:09:56 (0.17 h) avg: 0.544 W  
2025-11-12 11:55:52 suspend 31.060 Wh  
2025-11-12 12:17:14 resume 30.920 Wh  
consumed: 0.140 Wh dt: 00:21:22 (0.36 h) avg: 0.393 W  
2025-11-12 12:19:45 suspend 30.670 Wh  
2025-11-12 14:21:30 resume 30.110 Wh  
consumed: 0.560 Wh dt: 02:01:45 (2.03 h) avg: 0.276 W  
2025-11-12 14:32:58 suspend 29.210 Wh  
2025-11-12 16:20:21 resume 28.720 Wh  
consumed: 0.490 Wh dt: 01:47:23 (1.79 h) avg: 0.274 W

### To do:
Add log rotation.

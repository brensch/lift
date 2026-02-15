PS C:\WINDOWS\system32> net stop usbipd
The USBIP Device Host service is stopping.
The USBIP Device Host service was stopped successfully.

PS C:\WINDOWS\system32> net start usbipd
The USBIP Device Host service is starting.
The USBIP Device Host service was started successfully.

PS C:\WINDOWS\system32> usbipd attach --wsl --busid 9-3
usbipd: info: Using WSL distribution 'Ubuntu-24.04' to attach; the device will be available in all WSL 2 distributions.
usbipd: info: Detected networking mode 'nat'.
usbipd: info: Using IP address 172.24.96.1 to reach the host.
PS C:\WINDOWS\system32> usbipd bind --busid 9-3
usbipd: info: Device with busid '9-3' was already shared.
PS C:\WINDOWS\system32> usbipd detach --all
PS C:\WINDOWS\system32> usbipd attach --wsl --busid 9-3
usbipd: info: Using WSL distribution 'Ubuntu-24.04' to attach; the device will be available in all WSL 2 distributions.
usbipd: info: Detected networking mode 'nat'.
usbipd: info: Using IP address 172.24.96.1 to reach the host.
PS C:\WINDOWS\system32> usbipd bind --busid 9-3
usbipd: info: Device with busid '9-3' was already shared.
PS C:\WINDOWS\system32>
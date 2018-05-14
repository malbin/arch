# https://wiki.archlinux.org/index.php/Security

# encrypt on suspend
make sure the thing is set to hibernate when lid is shut by adding:
```shell
HandleLidSwitch=hibernate
HandleLidSwitchExternalPower=hibernate
```
to /etc/systemd/logind.conf

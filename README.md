Initial date: 20251005
Last updated: 20251005

## sbmon
sbmon is a system usage monitor originally intended for the Sway status bar.  
Currently there's cpu, disk, memory and networking usage.

---

![sbmon-20251005.png](https://raw.githubusercontent.com/esselfe/sbmon/refs/heads/main/sbmon-20251005.png)  

---

## Installation
You can run 'make install' or 'make uninstall' as root or as a normal user.  
The program's default install path is /usr/local and can be overriden like this:  
```
make PREFIX=/opt install
```

Other such variables available are 'SYSCONFDIR' and 'USRCONFDIR', which default  
to '/etc/sway' and '$HOME/.config/sway'.

SYSCONFDIR will be used when running 'make install' as root.  
USRCONFDIR will be used when running 'make install' as a normal user.  

---

## Author
Written by Stephane Fontaine (esselfe), licensed under the GPLv3.

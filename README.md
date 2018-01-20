# TSBE Demosystem konfig
folgende Systeme können konfiguriert werden:
* dnsmasq als DHCP, DNS und PXE Server
..* der Gateway soll auf 192.168.1.2 sein
..* die konfiguraion des zu installierenden Ubunu-Servers findet sich im Ordner "ubuntu-installation"
* deprecated ~~isc-dhcp mit tftp als DHCP und PXE Server~~
* puppet Server (achtung, muss dns-namen "puppet" haben. Mac zuerst bei dnsmasq eintragen!)

Die installation der jeweiligen Systeme muss als root erfolgen!
1. neue VM hochziehen (ubuntu Server)
2. sudo apt-get update und sudo apt-get upgrade
3. dieses GIT-Repo klonen
4. sudo su
5. entsprechendes Skript ausführen
6. im falle von dnsmasq sicherstellen, dass die IP-Config stimmt

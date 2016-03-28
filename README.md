1. Check out the source and setup the dot dir:

```
# cd ~
# mv .znc .znc_old 
# git clone https://github.com/cloudkitsch/oh-my-znc.git .znc
```

2. Edit the znc.conf and change all of this stuff

```
cd ~/.znc/configs
# cat znc.conf | grep "changeme"
<User changeme>
        AltNick = changeme_
        Ident = changeme
        Nick = changeme
```

3. Run makepass and edit the znc.conf again, scroll down to the bottom. Find the password section, run this command to generate a new one and replace it, ex:

```
# znc --makepass
[ ** ] Type your new password.
[ ?? ] Enter password: 
[ ?? ] Confirm password: 
[ ** ] Kill ZNC process, if it's running.
[ ** ] Then replace password in the <User> section of your config with this:

## cut here: open znc.conf and scroll down all the way to the bottom, replace the password block with this one:

<Pass password>
        Method = sha256
        Hash = 6bad4fbfe1c30558959e8ad74b365b0f1efa7f0e806bd728bf1ff87d8de244ef
        Salt = AEUTo-BLsvHy59X,uzz/
</Pass>
```
*Note: the default is "changeme" if you just want to test it but I highly reccomend that you change it anyway.*

4. Generate an SSL certificate for ZNC: 

```
openssl req -x509 -sha256 -nodes -days 1826 -newkey rsa:2048 -keyout ~/.znc/znc.key -out ~/.znc/znc.pem -subj "/CN=ChangeThisToYourNickname"
```

5. Builds the identserver module and allow a regular user to bind to port 113 

```
# cd ~/.znc/modules
# CXXFLAGS="-std=gnu++11" znc-buildmod identserver.cpp
```

6. This command will allow the module to bind to port 113 (by default only applications running as root can bind to < 1024.)

```
setcap 'cap_net_bind_service=+ep' $(which znc)
```

7. You may want to make sure to forward TCP/113 if you're behind NAT, and if you're using NF_CONNTRACK on your router, change your limits:

```
# sudo /sbin/sysctl -w net.netfilter.nf_conntrack_max = 196608
# sudo echo 24576 > /sys/module/nf_conntrack/parameters/hashsize
```

8.  To make it permanent after reboot, do this:

```
# sudo echo net.ipv4.netfilter.ip_conntrack_max = 196608 >> /etc/sysctl.conf
# sudo echo "options ip_conntrack hashsize=24576" >> /etc/modprobe.conf
```

9. You will also likely hit your hard limit with file descriptors really fast with this configuration, so change it:

```
sudo echo "* hard nofile 1024000" >> /etc/security/limits.conf
# (as regular user) 
ulimit -n 65536 
# (increase if needed, doubt you'll need much more than that though.)
```

10. Your ZNC server should be ready to start up, just run znc. Now you need to setup your client to work with it correctly:

10.1 for irssi, you'll want the following honestly irssi is the only client I can get to behave, everything else is really slow. So I've provided some scripts to make 
the experience a little bit better:

```
# cd ~ 
# mv .irssi .irssi_old 
# ln -s ~/.znc/irssi .irssi
```

10.2 now before starting irssi, change the "your-password-here" and "your-znc-bouncer-or-ip.com" to whatever you made it and then paste the script into a bash prompt. Copy the output of the
script and paste it into irssi. After the paste finishes type /save then type /quit and re-run irssi.

```
cd ~/.znc
for x in `cat tools/networks | tee`; do
	net=`echo $x | tr -d '.' | tr -d '-'`
	echo "/network add ${net}"
	echo "/server add -net ${net} -auto -ssl your-znc-bouncer-or-ip.com 6668 erratic/${net}:your-password-here"
done

```

10. SSL fingerprints: ZNC has issues with self signed certificates, so you need to grab the fingerprints and add them sometimes

```
cd ~/.znc
rm tools/fingerprints && echo "server,port,fingerprint" >> tools/fingerprints && cat configs/znc.conf | grep + | grep "Server" | tr -d '+' | awk '{print $3":"$4}' | parallel -j100 
tools/./generate_fingerprints.sh >> tools/fingerprints
```

10.1 After that finishes, copy and paste this script into a shell and then copy the output and paste it into irssi:

```
cd tools/
for x in `csvjoin -c server,server all_networks_ports_channels fingerprints | tr ',' ' ' | awk '{print $1","$NF}' | grep ":"`; do
    net=$(echo $x | tr ',' ' ' | tr -d '-' | tr -d '.' | awk '{print $1}')
    fp=$(echo $x | tr ',' ' ' | tr -d '-' | tr -d '.' | awk '{print $2}') 
    echo "/msg -${net} *status AddTrustedServerFingerprint ${fp}"
done
```

# Other handy things 

1. register your nick 

```
for x in `cat networks`; do 
    net=$(echo $x | tr -d '-' | tr -d ".")  
    echo "/msg -$net nickserv register changeme you@someemail.com"
done
```

2. if you need to enable some modules only for specific networks, pasting commands may cause segfaults, so: 

```
sed -i 's/JoinDelay = 0/JoinDelay = 0\n                LoadModule = nickserv/g' znc.conf
```

2.1 If you made the silly mistake of making all of your passwords for nickserv the same, try this:  
```
for x in `cat networks`; do                 
    echo $x,$(dd if=/dev/urandom bs=1024 count=1 2> /dev/null | sha256sum | base64 | head -c 8 ; echo)
done > newpasswords

for x in `cat newpasswords | tee`; do
    net=$(echo $x | tr ',' ' ' | awk '{print $1}' | tr -d '-' | tr -d '.')
    pass=$(echo $x | tr ',' ' ' | awk '{print $2}')
    echo "/msg -${net} nickserv set password ${pass}"
done


```

2.2 Sometimes modules are buggy, and you can't paste commands without crashing znc, so set one then copy the moddata to all 
of the others:

```
for x in `ls | tee`; do                                                                                                                                  
echo "IdentifyCmd PRIVMSG%20;Nickserv%20;identify%20;yournick%20;yourpass" > "./${x}/moddata/nickserv/.registry"
echo "IdentifyCmd PRIVMSG%20;Nickserv%20;identify%20;yourpass" >> "./${x}/moddata/nickserv/.registry"
echo "Password nsname%20;yournick" >> "./${x}/moddata/nickserv/.registry"
done

```


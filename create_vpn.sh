#!/bin/bash
# create vpn serivce cmd: run this script, output ip, username, password
# restart vpn service cmd: vpnrestart
# close vpn service cmd: killall pptpd

yum install -y ppp perl iptables >/dev/null 2>&1 

if [ "$(uname -p)" = "x86_64" ]
then
    wget -c http://poptop.sourceforge.net/yum/stable/packages/pptpd-1.3.4-2.rhel5.x86_64.rpm >/dev/null 2>&1 
    rpm -ivh pptpd-1.3.4-2.rhel5.x86_64.rpm >/dev/null 2>&1 
    rm -rf pptpd-1.3.4-2.rhel5.x86_64.rpm
else
    wget -c http://poptop.sourceforge.net/yum/stable/packages/pptpd-1.3.4-2.rhel5.i386.rpm >/dev/null 2>&1 
    rpm -ivh pptpd-1.3.4-2.rhel5.i386.rpm >/dev/null 2>&1 
    rm pptpd-1.3.4-2.rhel5.i386.rpm
fi


sed -i -e '/pptpd/ d' /etc/ppp/chap-secrets

cat > /bin/vpnrestart << EOF
echo 1 > /proc/sys/net/ipv4/ip_forward
killall pptpd >/dev/null 2>&1 
/sbin/iptables -F >/dev/null 2>&1 
/sbin/iptables -t nat -F >/dev/null 2>&1 
EOF


IPS=($(ifconfig | grep 'inet addr:' | awk -F'[ :]+' '{print $4}' | grep -v 127.0.0.1))
for((i=0; i<${#IPS[@]}; i++))
do
    IP=${IPS[$i]}
    cat > /etc/pptpd.${IP}.conf << EOF
option /etc/ppp/options.pptpd.${IP}
logwtmp
localip 10.1.$i.1
remoteip 10.1.$i.2-100
EOF

    cat > /etc/ppp/options.pptpd.${IP} << EOF
name pptpd.${IP}
ms-dns 8.8.8.8
ms-dns 8.8.4.4
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
idle 2592000
EOF
    
    USER="vpn${IP}"
    PASSWORD="${RANDOM}"
    echo "${USER} pptpd.${IP} ${PASSWORD} *" >> /etc/ppp/chap-secrets
    
    echo "pptpd -c /etc/pptpd.${IP}.conf -l ${IP} >/dev/null 2>&1" >> /bin/vpnrestart
    echo "iptables -t nat -I POSTROUTING -s 10.1.${i}.0/24 -j SNAT --to ${IP} >/dev/null 2>&1" >> /bin/vpnrestart
    
    echo -e "\nIP:${IP} \nUSER: ${USER}\nPASSWORD:${PASSWORD}\n"
    
done

chmod +x /bin/vpnrestart
/bin/vpnrestart
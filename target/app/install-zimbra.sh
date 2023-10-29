ch#!/bin/bash

set -e

ZIMBRA_DOWNLOAD_URL="https://gitlab.com/c-eee.org/zimbra_c-eee/-/raw/main/9/p33/UBUNTU20_64-KEPLER-900-20231010174750-FOSS-0033/zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750.tgz"
ZIMBRA_DOWNLOAD_HASH="c9a21046dcb0e4d9dc1a5618ec48012b6c8c5aa329bf4112192d05f8a7271bd1"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# abort, if the shell is not attached to a terminal
# (the menu-driven installation script requires user interaction)
if [ ! -t 0 ]; then
    echo "The executing shell is not attached to a terminal."
    echo "Aborting installation of Zimbra as the menu-driven setup script requires user interaction."
    echo "Please open a shell in the container and run /app/install-zimbra.sh manually..."
    exit 0
fi

# download zimbra
echo
echo "Downloading Zimbra..."
mkdir -p /install
cd /install
wget -O zcs.tgz $ZIMBRA_DOWNLOAD_URL
CALC_HASH=`sha256sum zcs.tgz | cut -d ' ' -f1`
if [ "$CALC_HASH" != "$ZIMBRA_DOWNLOAD_HASH" ]; then
    echo "Downloaded file is corrupt!"
    exit 1
fi

echo
echo "Extracting Zimbra..."
mkdir zcs
tar -C zcs -xvzf zcs.tgz --strip-components=1

echo
echo "Installing Zimbra..."
cd zcs
./install.sh

echo
echo "Retrieving some information needed for further steps..."
ADMIN_EMAIL=`sudo -u zimbra /opt/zimbra/bin/zmlocalconfig smtp_destination | cut -d ' ' -f3`
echo "- Admin e-mail address: $ADMIN_EMAIL"

echo
echo "Configuring Zimbra's brute-force detector (auditswatch) to send notifications to $ADMIN_EMAIL..."
# download and install missing auditswatch file
# ----------------------------------------------------------------------------------------------------------
mkdir -p /install/auditswatch
cd /install/auditswatch
wget -O auditswatch http://bugzilla-attach.zimbra.com/attachment.cgi?id=66723
mv auditswatch  /opt/zimbra/libexec/auditswatch
chown root:root /opt/zimbra/libexec/auditswatch
chmod 0755 /opt/zimbra/libexec/auditswatch

# configure auditswatch
# ----------------------------------------------------------------------------------------------------------
# The email address that we want to be worn when all the conditions happens.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_notice_user=$ADMIN_EMAIL
# The duration within the thresholds below refer to (in seconds)
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_threshold_seconds=3600
# IP/Account hash check which warns on 10 auth failures from an IP/Account combo within the specified time.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ipacct_threshold=10
# Account check which warns on 15 auth failures from any IP within the specified time.
# Attempts to detect a distributed hijack based attack on a single account.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_acct_threshold=15
# IP check which warns on 20 auth failures to any account within the specified time.
# Attempts to detect a single host based attack across multiple accounts.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ip_threshold=20
# Total auth failure check which warns on 100 auth failures from any IP to any account within the specified time.
# The recommended value on this is guestimated at 1% of active accounts for the Mailbox.
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_total_threshold=100
# check whether the service starts as expected
# ----------------------------------------------------------------------------------------------------------
sudo -u zimbra -- /opt/zimbra/bin/zmauditswatchctl start

echo 
echo "Installing Zextras Theme..."
mkdir -p /install/zextras
cd /install/zextras
wget  https://github.com/ZeXtras/zextras-theme/archive/master.zip
unzip master.zip
mv zextras-theme-master zextras
zip -r zextras.zip zextras
mv zextras.zip /tmp
chown zimbra:zimbra /tmp/zextras.zip
sed -i '/+ZimbraInstalledSkin/d' /opt/zimbra/bin/zmskindeploy
sed -i 's/harmony/zextras/g' /opt/zimbra/jetty/etc/zimbra.web.xml.in
sudo -u zimbra /opt/zimbra/bin/zmskindeploy  /tmp/zextras.zip
sudo -u zimbra /opt/zimbra/bin/zmmailboxdctl restart
echo "Installing zextras theme is completed"

echo
echo "Installing z-push for Zimbra"
sudo mkdir -p /install/z-push
cd /install/z-push
# installing  php and php dependancies for z-push...
sudo apt -y install php php-cli php-soap php-mbstring
# Installing php dependancies for backends...
sudo apt -y install php-imap php-curl libawl-php php-curl php-xml php-ldap
# Creating folder required for z-push..."
sudo mkdir /var/lib/z-push /var/log/z-push
sudo chmod 755 /var/lib/z-push /var/log/z-push
# Clone the latest zcs-push release from github
git clone https://github.com/c-eee-devops/zcs-zpush.git
# Create folder for log
mkdir /var/lib/z-push /var/log/z-push
chmod 755 /var/lib/z-push /var/log/z-push
chown zimbra:zimbra /var/lib/z-push /var/log/z-push
# Save z-push folder on /opt/





echo "Removing Zimbra installation files..."


cd /
rm -Rv /install

echo
echo "Adding Zimbra's Perl include path to search path..."
echo 'PERL5LIB="/opt/zimbra/common/lib/perl5"' >> /etc/environment

echo
echo "Generating stronger DH parameters (4096 bit)..."
sudo -u zimbra /opt/zimbra/bin/zmdhparam set -new 4096

echo
echo "Configuring cipher suites (as strong as possible without breaking compatibility and sacrificing speed)..."
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraReverseProxySSLCiphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA'
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsCiphers high
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsProtocols '!SSLv2,!SSLv3'
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsMandatoryCiphers high
sudo -u zimbra /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdTlsExcludeCiphers 'aNULL,MD5,DES'

echo
echo "Configuring default COS to use selected persona in the Return-Path of the mail envelope (important for privacy)."
sudo -u zimbra /opt/zimbra/bin/zmprov mc default zimbraSmtpRestrictEnvelopeFrom FALSE

echo
echo "Installing mail utilities to enable unattended-upgrades to send notifications."
echo "(Can be done after installing Zimbra only as bsd-mailx pulls in postfix that conflicts with the postfix package deployed by Zimbra.)"
apt-get install -y bsd-mailx

# let the container start Zimbra services next time
rm -f /.dont_start_zimbra

# restart services
echo
echo "Restarting services..."
sudo -u zimbra /opt/zimbra/bin/zmcontrol stop
/app/control-zimbra.sh start

exit 0

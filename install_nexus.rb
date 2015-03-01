#!/bin/bash

#
# Nexus Installation script
# Installation step 2
#

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo ""
echo "#"
echo "# Nexus installer"
echo "#"
echo ""
sleep 2

echo ""
echo "#"
echo "# 1) Upgrading system..."
echo "#"
echo ""

apt-get update
apt-get upgrade -y

echo ""
echo "#"
echo "# 2) Installing git..."
echo "#"
echo ""

apt-get install -y git

echo ""
echo "#"
echo "# 3) Installing ruby with rvm..."
echo "#"
echo ""

gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable --ruby
source /usr/local/rvm/scripts/rvm

echo ""
echo "#"
echo "# 4) Cloning Nexus..."
echo "#"
echo ""

cd /var/www
git clone https://github.com/hkparker/Nexus.git

echo ""
echo "#"
echo "# 5) Installing gems..."
echo "#"
echo ""

bundle install
cd -

echo ""
echo "#"
echo "# 6) Starting on boot with cron..."
echo "#"
echo ""



echo ""
echo ""
echo ""
echo ""
echo "Setup complete!  Reboot this nexus then visit /add_nexus on your controller to finish."

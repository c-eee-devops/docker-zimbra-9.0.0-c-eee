# Docker Image with Zimbra 9.0.0  OSE by C-EEE.ORG

## Overview

This image contains everything required to download, install, and run the [Zimbra](https://www.zimbra.com/) collaboration suite [FOSS]() Edition built by [C-EEE.ORG](https://c-eee.org) from source code accessible at [zm-build](https://github.com/Zimbra/zm-build) at [GitHub](https://github.com/). Zimbra is not present in the image. 

1. The container initially installs a basic Ubuntu 20.04 LTS into a docker volume. This installation serves as Zimbra's root filesystem, allowing Zimbra to interact with the environment while keeping everything consistent and permanent - even if the container is upgraded. This also indicates that downloading a new image version does not update the Ubuntu installation on the docker volume.
  
2. To decrease the possibility of security vulnerabilities, the container configures Ubuntu's *unattended upgrades* package to automatically install official updates. To find out how and why should you do it, [learn more here](https://www.kolide.com/features/checks/ubuntu-unattended-upgrades).

3. The container supports IPv6 and has a global IPv6 address. It also has packet filtering configured to prevent common attacks and access to non-public ports.

## Install `docker` using the Apt repository

You must first configure the Docker repository before installing Docker Engine for the first time on a new host machine. After that, you may use the repository to install and update Docker.

1. Set up Docker's Apt repository.

   ```bash
   # Add Docker's official GPG key:
   sudo apt-get update
   sudo apt-get install ca-certificates curl gnupg
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   sudo chmod a+r /etc/apt/keyrings/docker.gpg

   # Add the repository to Apt sources:
   echo \
   "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] 
   https://download.docker.com/linux/ubuntu \
   "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   ```

2. Install the Docker packages.

   ```bash
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

3. Check your installation

   ```bash
   sudo docker version
   ```

4. Add current user to `docker` group
   
   ```bash
   sudo usermod -aG docker $USER
   ```

5. Let current user to be a member of `docker` group without logoff & logon

   ```bash
   newgrp $USER
   ```
## Deploying Zimbra on Docker Host

### Overview

This section explains how to start the Zimbra container on a standard Docker host.

### Step 1: - Configuring a User-Defined Network

- If you don't already have a user-defined network for public services, you can establish a simple bridge network (named `frontend` in the example below) and define the subnets from which Docker will assign IP addresses to containers.

- As you will most likely only have one IPv4 address for your server, you should select a subnet from the site-local ranges (`10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`).

- Docker handles connecting published services to the server's public IPv4 address.

- Any IPv6-enabled server nowadays has at least a /64 subnet assigned, thus any single container can have its own IPv6 address without the need for network address translation (NAT). As a result, you should select an IPv6 subnet that is part of the subnet that your server is assigned to.
  
- Docker advises using a subnet of at least /80 so that it can assign IP addresses by ORing the container's (virtual) MAC address with the provided subnet.

  ```bash
  docker network create -d bridge \
    --subnet 192.168.0.0/24 \
    --subnet 2001:xxxx:xxxx:xxxx::/80 \
    --ipv6 \
  frontend
  ```
### Step 2 - Create a Volume for the Zimbra Container

The zimbra container installs a minimalistic Ubuntu 20.04 LTS and Zimbra onto a docker volume. You can create a named volume using the following command:

```bash
docker volume create zimbra-data
````

### Step 3 - Install Zimbra

- Before installing Zimbra, you should ensure that your DNS contains the following records:

- An A record mapping the FQDN of the Zimbra container to the public `IPv4` address of the docker host (e.g. `mail.c-eee.org`), the docker host maps the service ports to the container.

- An  `AAAA` record mapping the `FQDN` of the Zimbra container to its public `IPv6` address (e.g. `mail.c-eee.org`)

- A `MX` record with the hostname of the Zimbra container (as specified by the `A/AAAA` records)

- The command below will install Zimbra on the newly created volume.

- You will be able to configure Zimbra utilizing the menu-driven installation script. 

- You can install all features except the `DNS` Cache, which will interfere with the container's  `DNS` cache. 

- Please replace the hostname in the  `A/AAAA` DNS entries with the hostname you selected.

- Because the `IPv4` address through which the container would be publicly accessible is really assigned to the docker host, the installation process will complain about a DNS problem. Ignore the warning and continue. It will eventually function.

- Clone the reposotory to you Ubuntu 20.04 doker host

  ```bash
  git clone https://github.com/ceeedevops/docker-zimbra-9.0.0-c-eee.git
  ```
  
-  Access the repository directory

   ```bash
   cd docker-zimbra-9.0.0-c-eee
   ```

- Build the  container

  ```bash
  ,/build.sh
  ```
-  Start the container

  ```bash
  docker run -it \
             --rm \
             --ip6=2001:xxxx:xxxx:xxxx::2 \
             --network frontend \
             --hostname mail.c-eee.org \
             -p 25:25 \
             -p 80:80 \
             -p 110:110 \
             -p 143:143 \
             -p 443:443 \
             -p 465:465 \
             -p 587:587 \
             -p 993:993 \
             -p 995:995 \
             -p 5222:5222 \
             -p 5223:5223 \
             -p 7071:7071 \
             --volume zimbra-data:/data \
             --cap-add NET_ADMIN \
             --cap-add SYS_ADMIN \
             --cap-add SYS_PTRACE \
             --security-opt apparmor=unconfined \
             c-eee.org/zimbra \
             run-and-enter
  ```
- To function correctly, the container requires a few more characteristics. 

- To configure network interfaces and the iptables firewall, the `NET_ADMIN` capability is required. 

- The `SYS_ADMIN` capability is required to configure the chrooted environment in which Zimbra runs.

- To for `rsyslog` to `start/stop` effectively, the `SYS_PTRAC`E capability is required.
  
- `AppArmor` protection must also be disabled in order to set up the `chrooted` environment.

- The  `run-and-enter` command instructs the container to open a shell within the container at the end. 

- You can also access the Ubuntu installation with Zimbra directly by typing `run-and-enter-zimbra`.

- The default command is executed.

- It simply starts a script that initializes the container and waits for the container to be closed before gracefully shutting down Zimbra (and related services).

- Once the manual configuration is complete, you will most likely merely execute the container in the background with the `run` command:

- Set up the enviorenment required to install `zimbra`
  
  ```bash
  cd /app
  chmod +x *.sh
  ./setup-enviorenment.sh
  ```
- To install `zimbra`  run:

  ```bash
  ./install-zimbra.sh
  ```
- Output:

  ```bash
  Downloading Zimbra...
  2023-10-18 14:06:03--  https://gitlab.com/c-eee.org/zimbra_c-eee/-/raw/main/9/p33/UBUNTU20_64-KEPLER-900-20231010174750-FOSS-0033/zcs- 
  9.0.0_GA_0033.UBUNTU20_64.20231010174750.tgz
  Resolving gitlab.com (gitlab.com)... 172.65.251.78, 2606:4700:90:0:f22e:fbec:5bed:a9b9
  Connecting to gitlab.com (gitlab.com)|172.65.251.78|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 256776246 (245M) [application/x-gtar]
Saving to: 'zcs.tgz'

zcs.tgz                                100%[============================================================================>] 244.88M  50.0MB/s    in 6.0s

2023-10-18 14:06:10 (40.7 MB/s) - 'zcs.tgz' saved [256776246/256776246]


Extracting Zimbra...
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/.BUILD_PLATFORM
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/install.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/Migration_Exch_Admin.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/Zimbra iCalendar Migration Guide.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/MigrationWizard_Domino.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/Import_Wizard_Outlook.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/quick_start.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/MigrationWizard.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/RNZCSO_2005Beta.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/admin.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/Fedora Server Config.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/User Instructions for ZCS Import Wizard.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/OSmultiserverinstall.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/en_US/zimbra_user_guide.pdf
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/docs/zcl.txt
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/.BUILD_RELEASE_CANDIDATE
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/.BUILD_RELEASE_NO
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/README.txt
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/data/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/data/versions-init.sql
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/addUser.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/modules/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/modules/packages.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/modules/postinstall.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/modules/getconfig.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/utilfunc.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/util/globals.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/.BUILD_NUM
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/readme_binary_en_US.txt
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/lib/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/lib/jars/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/.BUILD_TYPE
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-spell_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf_9.0.0.1694759969-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-core-libs_9.0.0.1682575014-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-webclient-war_9.0.0.1695820709-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-store_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-imapd_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-native-lib_9.0.0.1521095672-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-service_9.0.0.1694759969-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-core-libs_9.0.0.1682575014-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf-rights_9.0.0.1610613206-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-native-lib_9.0.0.1521095672-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf-msgs_9.0.0.1677496878-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-proxy_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-service_9.0.0.1694759969-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-core-jar_9.0.0.1694759969-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-db_9.0.0.1694759969-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf_9.0.0.1694759969-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mta_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-store-libs_9.0.0.1682575014-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-store-libs_9.0.0.1682575014-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-db_9.0.0.1694759969-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf-msgs_9.0.0.1677496878-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-docs_9.0.0.1680161581-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-timezone-data_4.0.0.1693034045-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf-attrs_9.0.0.1692683453-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-core-jar_9.0.0.1694759969-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-dnscache_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-apache_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/Packages
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-webclient-war_9.0.0.1695820709-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-timezone-data_4.0.0.1693034045-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-docs_9.0.0.1680161581-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf-rights_9.0.0.1610613206-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-admin-console-war_9.0.0.1695220943-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-conf_9.0.0.1677496878-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-ldap_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-snmp_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-core_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-common-mbox-conf-attrs_9.0.0.1692683453-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-logger_9.0.0.GA.0033.UBUNTU20.64_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-war_9.0.0.1694759969-1.u20_amd64.changes
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-war_9.0.0.1694759969-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-conf_9.0.0.1677496878-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/packages/zimbra-mbox-admin-console-war_9.0.0.1695220943-1.u20_amd64.deb
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/bin/
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/bin/checkLicense.pl
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/bin/zmValidateLdap.pl
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/bin/get_plat_tag.sh
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/bin/checkService.pl
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/bin/zmdbintegrityreport
zcs-9.0.0_GA_0033.UBUNTU20_64.20231010174750/.BUILD_TIME_STAMP

Installing Zimbra...

Operations logged to /tmp/install.log.suHabPD2
Checking for existing installation...
    zimbra-drive...NOT FOUND
    zimbra-imapd...NOT FOUND
    zimbra-license-tools...NOT FOUND
    zimbra-license-extension...NOT FOUND
    zimbra-network-store...NOT FOUND
    zimbra-network-modules-ng...NOT FOUND
    zimbra-chat...NOT FOUND
    zimbra-connect...NOT FOUND
    zimbra-talk...NOT FOUND
    zimbra-ldap...NOT FOUND
    zimbra-logger...NOT FOUND
    zimbra-mta...NOT FOUND
    zimbra-dnscache...NOT FOUND
    zimbra-snmp...NOT FOUND
    zimbra-store...NOT FOUND
    zimbra-apache...NOT FOUND
    zimbra-spell...NOT FOUND
    zimbra-convertd...NOT FOUND
    zimbra-memcached...NOT FOUND
    zimbra-proxy...NOT FOUND
    zimbra-archiving...NOT FOUND
    zimbra-core...NOT FOUND


----------------------------------------------------------------------
PLEASE READ THIS AGREEMENT CAREFULLY BEFORE USING THE SOFTWARE.
SYNACOR, INC. ("SYNACOR") WILL ONLY LICENSE THIS SOFTWARE TO YOU IF YOU
FIRST ACCEPT THE TERMS OF THIS AGREEMENT. BY DOWNLOADING OR INSTALLING
THE SOFTWARE, OR USING THE PRODUCT, YOU ARE CONSENTING TO BE BOUND BY
THIS AGREEMENT. IF YOU DO NOT AGREE TO ALL OF THE TERMS OF THIS
AGREEMENT, THEN DO NOT DOWNLOAD, INSTALL OR USE THE PRODUCT.

License Terms for this Zimbra Collaboration Suite Software:
https://www.zimbra.com/license/zimbra-public-eula-2-6.html
----------------------------------------------------------------------
Do you agree with the terms of the software license agreement? [N] y

Use Zimbra's package repository [Y] y

Warning: apt-key output should not be parsed (stdout is not a terminal)
Importing Zimbra GPG key

Configuring package repository

Checking for installable packages

Found zimbra-core (local)
Found zimbra-ldap (local)
Found zimbra-logger (local)
Found zimbra-mta (local)
Found zimbra-dnscache (local)
Found zimbra-snmp (local)
Found zimbra-store (local)
Found zimbra-apache (local)
Found zimbra-spell (local)
Found zimbra-memcached (repo)
Found zimbra-proxy (local)
Found zimbra-drive (repo)
Found zimbra-imapd (local)

Select the packages to install

Install zimbra-ldap [Y] y

Install zimbra-logger [Y] y

Install zimbra-mta [Y] y

Install zimbra-dnscache [Y] n

Install zimbra-snmp [Y] y

Install zimbra-store [Y] y

Install zimbra-apache [Y] y

Install zimbra-spell [Y] y

Install zimbra-memcached [Y] y

Install zimbra-proxy [Y] y

Install zimbra-drive [Y] y

Install zimbra-imapd (BETA - for evaluation only) [N] n

Install zimbra-chat [Y] y
Checking required space for zimbra-core
Checking space for zimbra-store
Checking required packages for zimbra-store
zimbra-store package check complete.

Installing:
    zimbra-core
    zimbra-ldap
    zimbra-logger
    zimbra-mta
    zimbra-snmp
    zimbra-store
    zimbra-apache
    zimbra-spell
    zimbra-memcached
    zimbra-proxy
    zimbra-drive
    zimbra-chat

The system will be modified.  Continue? [N] y

Beginning Installation - see /tmp/install.log.suHabPD2 for details...

                          zimbra-core-components will be downloaded and installed.
                            zimbra-timezone-data will be installed.
                         zimbra-common-mbox-conf will be installed.
                         zimbra-common-core-libs will be installed.
                   zimbra-common-mbox-native-lib will be installed.
                    zimbra-common-mbox-conf-msgs will be installed.
                          zimbra-common-core-jar will be installed.
                           zimbra-common-mbox-db will be installed.
                         zimbra-common-mbox-docs will be installed.
                   zimbra-common-mbox-conf-attrs will be installed.
                  zimbra-common-mbox-conf-rights will be installed.
                                     zimbra-core will be installed.
                          zimbra-ldap-components will be downloaded and installed.
                                     zimbra-ldap will be installed.
                                   zimbra-logger will be installed.
                           zimbra-mta-components will be downloaded and installed.
                                      zimbra-mta will be installed.
                          zimbra-snmp-components will be downloaded and installed.
                                     zimbra-snmp will be installed.
                         zimbra-store-components will be downloaded and installed.
                       zimbra-jetty-distribution will be downloaded and installed.
                       zimbra-mbox-webclient-war will be installed.
                                 zimbra-mbox-war will be installed.
                                zimbra-mbox-conf will be installed.
                             zimbra-mbox-service will be installed.
                          zimbra-mbox-store-libs will be installed.
                   zimbra-mbox-admin-console-war will be installed.
                                    zimbra-store will be installed.
                        zimbra-apache-components will be downloaded and installed.
                                   zimbra-apache will be installed.
                         zimbra-spell-components will be downloaded and installed.
                                    zimbra-spell will be installed.
                                zimbra-memcached will be downloaded and installed.
                         zimbra-proxy-components will be downloaded and installed.
                                    zimbra-proxy will be installed.
                                    zimbra-drive will be downloaded and installed (later).
                                     zimbra-chat will be downloaded and installed (later).

Downloading packages (10):
   zimbra-core-components
   zimbra-ldap-components
   zimbra-mta-components
   zimbra-snmp-components
   zimbra-store-components
   zimbra-jetty-distribution
   zimbra-apache-components
   zimbra-spell-components
   zimbra-memcached
   zimbra-proxy-components
      ...done

Removing /opt/zimbra
Removing zimbra crontab entry...done.
Cleaning up zimbra init scripts...done.
Cleaning up /etc/security/limits.conf...done.

Finished removing Zimbra Collaboration Server.


Installing repo packages (10):
   zimbra-core-components
   zimbra-ldap-components
   zimbra-mta-components
   zimbra-snmp-components
   zimbra-store-components
   zimbra-jetty-distribution
   zimbra-apache-components
   zimbra-spell-components
   zimbra-memcached
   zimbra-proxy-components
      ...done

Installing local packages (25):
   zimbra-timezone-data
   zimbra-common-mbox-conf
   zimbra-common-core-libs
   zimbra-common-mbox-native-lib
   zimbra-common-mbox-conf-msgs
   zimbra-common-core-jar
   zimbra-common-mbox-db
   zimbra-common-mbox-docs
   zimbra-common-mbox-conf-attrs
   zimbra-common-mbox-conf-rights
   zimbra-core
   zimbra-ldap
   zimbra-logger
   zimbra-mta
   zimbra-snmp
   zimbra-mbox-webclient-war
   zimbra-mbox-war
   zimbra-mbox-conf
   zimbra-mbox-service
   zimbra-mbox-store-libs
   zimbra-mbox-admin-console-war
   zimbra-store
   zimbra-apache
   zimbra-spell
   zimbra-proxy
      ...done

Installing extra packages (2):
   zimbra-drive
   zimbra-chat
      ...done

Running Post Installation Configuration:
Operations logged to /tmp/zmsetup.20231018-141343.log
Installing LDAP configuration database...done.
Setting defaults...

DNS ERROR resolving MX for mail.c-eee.org
It is suggested that the domain name have an MX record configured in DNS
Change domain name? [Yes]

```
  


  ```bash
  docker run --name zimbra \ 
             --detach \
             --rm \
             --ip6=2001:xxxx:xxxx:xxxx::2 \
             --network frontend \
             --hostname mail.c-eee.org \
             -p 25:25 \
             -p 80:80 \
             -p 110:110 \
             -p 143:143 \
             -p 443:443 \
             -p 465:465 \
             -p 587:587 \
             -p 993:993 \
             -p 995:995 \
             -p 5222:5222 \
             -p 5223:5223 \
             -p 7071:7071 \
             --volume zimbra-data:/data \
             --cap-add NET_ADMIN \
             --cap-add SYS_ADMIN \
             --cap-add SYS_PTRACE \
             --security-opt apparmor=unconfined \
             c-eee.org/zimbra \
             run
  ```

## Maintenance

1. If the associated volume is empty, the container installs a full Ubuntu 20.04 LTS installation along with Zimbra. This also implies that executing an updated docker image does not update the installation on the disk.
   
2.  The installation is kept up to date because Ubuntu's `unattended upgrades` program automatically installs official updates. If you do not want the installation to be automatically updated,
   
3.  To stop unattended upgrades after the installation by setting, in case if you don't want to have it some reason.

- Open the configuration file:

  ```bash
  nano /etc/apt/apt.conf.d/20auto-upgrades
  ```

- Add the following configuration parameter:
  
  ```bash
  APT::Periodic::Unattended-Upgrade "0"; 
  ```

4. To manually install updates, launch a shell in the container using the following command:

   ```bash 
   docker exec -it zimbra /bin/bash
   ```

5.  The entire Ubuntu installation is kept in `/data`, so you need to `chroot` to dive into the environment:

    ```bash
    chroot /data /bin/bash
    ```

You can now deal with the installation as you would a conventional Ubuntu installation, with some limitations. Some kernel calls are restricted by the default `seccomp` profile in Docker, therefore you may need to alter this. Furthermore,`systemd` is broken, thus you must use init scripts to `start/stop` services.

5. First and foremost, you should keep your Ubuntu installation up to date by running the following tasks on a regular basis:

   ```bash
   apt-get update
   apt-get upgrade
   ```

6. If a new Zimbra installation is available, you must manually update it to ensure that any adjustments made since the first setup are appropriately re-applied. A new image that installs a new version of Zimbra **WILL NOT** upgrade an existing installation.

## Security

### Transport Security (TLS)

- By default Zimbra generates a self-signed certificate for TLS. As self-signed certificates are not trusted web browsers will complain about it.

-   To use a certificate issued by a trusted certification authority (CA),  you can tell the container to set it in by providing the private key at `/data/app/tls/zimbra.key` and the certificate at `/data/app/tls/zimbra.crt`.

- The container keeps track of changes to the certificate file and re-configures Zimbra, if necessary.

- It is recommended to mount a volume with the key and the certificate at `/data/app/tls` and use it for exchanging the certificate.

- The certificate *should* contain the certificate chain up to the root certificate.

- If a certificate of an intermediate CA or root CA is missing, the container will try to download the missing certificates using the *Authority Information Access* extension (if available).

- Furthermore 4096 bit DH parameters are generated improving the security level of the key exchange.

#### HTTP Transport Security (HSTS)

If the container is `directly` linked to the internet (without the use of a reverse proxy), HTTP Transport Security (`HSTS`) should be enabled to instruct web browsers to only connect to Zimbra through HTTPS. This can be accomplished as follows:

```bash
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf +zimbraResponseHeader "Strict-Transport-Security: max-age=31536000"
```

The configuration passes the popular SSL/TLS server tests:
- [SSL Labs](https://www.ssllabs.com/ssltest/) (supports HTTPS only)
- [Online Domain Tools](http://ssl-checker.online-domain-tools.com/) (supports HTTPS, SMTP, IMAP, POP)
- [High-Tech-Bridge](https://www.htbridge.com/ssl/) (supports HTTPS, SMTP, IMAP, POP)

### Firewall

The container configures the firewall allowing only the following services to be accessed from the public internet.

| Port     | Description                             |
| :------- | :-------------------------------------- |
| 25/tcp   | SMTP                                    |
| 80/tcp   | HTTP                                    |
| 110/tcp  | POP3                                    |
| 143/tcp  | IMAP                                    |
| 443/tcp  | HTTP over TLS                           |
| 465/tcp  | SMTP over SSL                           |
| 587/tcp  | SMTP (submission, for mail clients)     |
| 993/tcp  | IMAP over TLS                           |
| 995/tcp  | POP3 over TLS                           |
| 5222/tcp | XMPP                                    |
| 5223/tcp | XMPP (default legacy port)              |
| 7071/tcp | HTTPS (admin panel)                     |

- The packet filter prevents access to backend services such as LDAP, MariaDB, or the Jetty server. 

- Access to webmail via HTTP(S) as well as mail access via POP(S) and IMAP(S) are proxied by NGINX shipped with Zimbra adding an extra layer of security.

- Secure inter-process communication will be enabled if you install Zimbra using this image with the default settings.

- You can turn off the above feature. Because Zimbra components communicate without encryption, it improves overall system performance. This isn't a problem because everything runs on the same host, even within the same container.
 
- Furthermore, the packet filter includes a few rules that guard against common threats:
  
  - TCP floods (except SYN floods)
    
  - Bogus flags in TCP packets

  - RH0 packets (can be used for DoS attacks)

  - Ping of Death

### Mitigating Denial of Service (DoS) Attacks

#### HTTP Request Rate Limiting

Zimbra provides a simple mechanism to mitigate DoS attacks by rate-limiting HTTP requests per IP address.

At first the `zimbraHttpDosFilterDelayMillis` setting determines how to handle requests exceeding the rate-limit.
`-1` simply rejects the request (default). Any other positive value applys a delay (in ms) to the request to throttle it down. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpDosFilterDelayMillis -1
```

The `zimbraHttpDosFilterMaxRequestsPerSec` setting determines the maximum number of requests that are allowed per second. The default value is `30`. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpDosFilterMaxRequestsPerSec 30
```

At last the `zimbraHttpThrottleSafeIPs` setting determines IP addresses or IP address ranges (in CIDR notation) that should not be throttled. By default the whitelist is empty, but loopback adresses are always whitelisted. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpThrottleSafeIPs 10.1.2.3/32 zimbraHttpThrottleSafeIPs 192.168.4.0/24
```

Alternatively you can add values to an existing list:

```
sudo -u zimbra -- zmprov mcf +zimbraHttpThrottleSafeIPs 10.1.2.3/32
sudo -u zimbra -- zmprov mcf +zimbraHttpThrottleSafeIPs 192.168.4.0/24
```

### Mitigating Brute Force Attacks

Zimbra comes with a mechanism that blocks IP addresses, if there are too many failed login attempts coming from the address. The default values are usually a good starting point, but depending on the deployment it might be useful to adjust the settings.

At first the `zimbraInvalidLoginFilterDelayInMinBetwnReqBeforeReinstating` setting determines the time (in minutes) to block an IP address that has caused too many login attempts. The default value is `15`. The setting can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterDelayInMinBetwnReqBeforeReinstating 15
```

The setting `zimbraInvalidLoginFilterMaxFailedLogin` determines the number of failed login attempts before an IP address gets blocked. The default value is `10`. It can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterMaxFailedLogin 10
```

At last the setting `zimbraInvalidLoginFilterReinstateIpTaskIntervalInMin` determines the interval (in minutes) betwen running the process to unblock IP addresses. The default value is `5`. Usually there is no need to tweak it, but it can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterReinstateIpTaskIntervalInMin 5
```

### Monitoring Authentication Activity

The container configures Zimbra's brute-force detection *zmauditswatch*. It monitors authentication activity and sends an email to a configured recipient notifying the recipient of a possible attack. The default recipient is the administrator (as returned by `zmlocalconfig smtp_destination`). It does not block the attack!

The initial parameter set is as follows:

| Parameter                         | Value   | Description                       
| :-------------------------------- | :-----: | :--------------------------------------------------------------------------------------
| zimbra_swatch_notice_user         | *admin* | The email address of the person receiving notifications about possible brute-force attacks.
| zimbra_swatch_threshold_seconds   | 3600    | Detection time the thresholds below refer to (in seconds).
| zimbra_swatch_ipacct_threshold    | 10      | IP/Account hash check which warns on *xx* auth failures from an IP/Account combo within the specified time.
| zimbra_swatch_acct_threshold      | 15      | Account check which warns on *xx* auth failures from any IP within the specified time. Attempts to detect a distributed hijack based attack on a single account.
| zimbra_swatch_ip_threshold        | 20      | IP check which warns on *xx* auth failures to any account within the specified time. Attempts to detect a single host based attack across multiple accounts.
| zimbra_swatch_total_threshold     | 100     | Total auth failure check which warns on *xx* auth failures from any IP to any account within the specified time.

In most cases the parameters should be ok, but if you need to tune them, the following commands can be used to change the parameters:

```bash
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_notice_user=admin@c-eee.org
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_threshold_seconds=3600
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ipacct_threshold=10
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_acct_threshold=15
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ip_threshold=20
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_total_threshold=100
```

## Manual Adjustments Improving Security

### Enabling Domain Key Identified Mail (DKIM)

- `DKIM` (Domain Keys Identified Mail) is an email authentication technology used to identify email spoofing.
  
- It enables the receiver to verify that an email claiming to be from a given domain was truly allowed by the domain's owner.

- Its purpose is to prevent counterfeit sender addresses in emails, which are commonly exploited in phishing and email spam.

- `DKIM` allows a domain to associate its name with an email message by attaching a digital signature to it. 

- The signer's public key, which is published in the DNS, is used for verification. 

- A valid signature ensures that specific sections of the email (potentially including attachments) have not been altered since the signature was placed. 

- `DKIM` signatures are typically not visible to end users since they are affixed or validated by the infrastructure rather than the message's creators and recipients.

- `DKIM` varies from end-to-end digital signatures in this regard.

To enable `DKIM` signing you only need to run the following command (replace the domain name accordingly):

```bash
sudo -u zimbra -- /opt/zimbra/libexec/zmdkimkeyutil -a -d c-ceee.org
```
- This will generate a 2048-bit RSA key and enable DKIM signing for the domain supplied. 

- To complete the setting, you must publish the TXT record produced by `zmdkimkeyutil` in your `DNS`. 

- The `TXT` record has the name `AB6EFD30-2AA8-11E8-ACDA-A71CCC6989A6._domainkey`, whilst the DKIM selector is `AB6EFD30-2AA8-11E8-ACDA-A71CCC6989A6` 

The `DKIM` record has the following value:

```bash
v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmQ0nDvzpJn4b6nvvTDw2N0/Glcj24w0ZyTgNW1h5zNEEmxiH+7TuTcRvCVmBIHrY/anAtdiMZ60leQqo2USjI3ixE7Y1AewvjP95yS/WRq3Khoi7E2JsucreMcrf5WkVPsJd6G1Aw2uBGG/h/lyfjGYtpOjjnNqEb9Nxh3eMwATYNFUI55PVuTI405yR12SUPRomI2QvqiqTW2
```

- After a few minutes, you should be able to use the [DKIM Test](http://www.appmaildev.com/en/dkim) to see if DKIM signing works.
  
- Simply send an email to the generated address and wait for the report.

### Sender Policy Framework (SPF)

- The `Sender Policy Framework (SPF)` is a simple email-validation system designed to identify email spoofing by providing a means for receiving mail exchangers to verify that incoming mail from a domain originates from a host approved by the domain's administrators. 

- The list of approved transmitting hosts for a domain is published in the domain's Domain Name System (DNS) records as a specially structured `TXT` record.
  
- Because email spam and phishing frequently use forged "from" addresses, publishing and validating SPF records are anti-spam measures.
  
- To enable `SPF` you need to add a `TXT` record to your `DNS`. 

- The name of the `TXT` record must be the name of the `domain` the SPF policy refers to. 

- The value of the `TXT` record defines the policy. 

- A simple, but effective policy is:

  ```
  v=spf1 mx a ~all
  ```

- This informs other mail servers to accept messages from a mail server whose IP address is specified in the DNS of the same domain by A or AAAA records.
  
- Furthermore, all domain mail exchangers (designated by MX records) are permitted to send mail for the domain.
  
- Finally, all instructs other mail servers to treat policy violations as soft fails, i.e. the mail is marked but not rejected.
  
- This is most effective when combined with a DMARC policy (see below).
  
- The SPF syntax documentation explains you to create your own SPF policy.

A few minutes after setting the SPF record you can use one of the following tools to check it:

- [MxToolbox](https://mxtoolbox.com/spf.aspx)
  
- [Dmarcian SPF Surveyer](https://dmarcian.com/spf-survey/)

### Domain-based Message Authentication, Reporting and Conformance (DMARC)

- The `Domain-based Message Authentication, Reporting, and Conformance (DMARC)` system detects and prevents email spoofing.
  
- It is meant to counteract some phishing and email spam techniques, such as emails with counterfeit sender addresses that look to come from respectable businesses.
  
- `DMARC`, as defined in RFC 7489, prevents unauthorized use of the precise domain name in the 'From:' field of email message headers.

- DMARC is developed on top of the two previously mentioned techniques, *DomainKeys Identified Mail (DKIM)* and the *Sender Policy Framework (SPF). 

- It enables the domain's administrative owner to post a policy governing whether mechanism (DKIM, SPF, or both) is used when sending email from that domain and how the receiver should handle errors.
  
- It also includes a system for reporting actions taken in accordance with such policies. It thereby coordinates the DKIM and SPF results and specifies under what conditions the 'From:' header field, which is frequently accessible to end users, should be regarded valid.

- To enable DMARC you need to add a TXT record to your DNS. The name of the TXT record must be `_dmarc`.

- The value of the TXT record defines how mail servers receiving mail from your domain should act.

- A simple, but proven record is...

  ```bash
  v=DMARC1; p=quarantine; rua=mailto:dmarc@my-domain.com; ruf=mailto:dmarc@c-eee.org; sp=quarantine
  ```

- This notifies other mail servers to accept emails only if the `DKIM` signature is available and genuine, as well as if the `SPF` policy is met. 

- If both checks fail, the letter should be he`ld (quarantined) and not delivered.

- Aggregate reports (`rua`) and forensic data (`ruf`) will be sent to `dmarc@c-eee.org` by mail servers. 

- The official [DMARC website](https://dmarc.org) contains extensive material on how `DMARC` works and how it can be adjusted to meet your specific needs (if you require finer-grained control over `DMARC` parameters). 

- Setting up a bespoke DMARC policy is aided by [Kitterman's DMARC Assistant](http://www.kitterman.com/dmarc/assistant.html).

A few minutes after setting the DMARC record in your DNS, you can check it using one of the following tools:

- [MxToolbox](https://mxtoolbox.com/DMARC.aspx)
- [Dmarcian DMARC Inspector](https://dmarcian.com/dmarc-inspector/)
- [Proofpoint DMARC Check](https://stopemailfraud.proofpoint.com/dmarc/)

### Rejecting false `Mail From` addresses

[!IMPORTANT] 
When receiving mail, Zimbra is set up to accept any sender address. This could pose a security risk because an attacker could send emails to Zimbra users while impersonating other users. The following resources can help you increase your security:

- [Rejecting false "mail from" addresses](https://wiki.zimbra.com/wiki/Rejecting_false_%22mail_from%22_addresses)
  
- [Enforcing a match between FROM address and sasl username](https://wiki.zimbra.com/wiki/Enforcing_a_match_between_FROM_address_and_sasl_username_8.5)

To summarize, the following actions must be taken in order to reject bogus "mail from" addresses and allow authenticated users to utilize only their own identities (mail adresses):

```bash
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedRecipient yes
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedSender yes
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdSenderLoginMaps proxy:ldap:/opt/zimbra/conf/ldap-slm.cf +zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch
```

Furthermore you need to edit the file `/opt/zimbra/conf/zmconfigd/smtpd_sender_restrictions.cf` and add `reject_sender_login_mismatch` after the `permit_mynetworks` line. 

It should look like the following:

```bash
%%exact VAR:zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch%%
%%contains VAR:zimbraMtaSmtpdSenderRestrictions check_sender_access lmdb:/opt/zimbra/conf/postfix_reject_sender%%
%%contains VAR:zimbraServiceEnabled cbpolicyd^ check_policy_service inet:localhost:%%zimbraCBPolicydBindPort%%%%
%%contains VAR:zimbraServiceEnabled amavis^ check_sender_access regexp:/opt/zimbra/common/conf/tag_as_originating.re%%
permit_mynetworks
reject_sender_login_mismatch
permit_sasl_authenticated
permit_tls_clientcerts
%%contains VAR:zimbraServiceEnabled amavis^ check_sender_access regexp:/opt/zimbra/common/conf/tag_as_foreign.re%%
```

[!IMPORTANT] 
As all manual changes done to Zimbra's configuration files changes to `smtpd_sender_restrictions.cf` are overwritten when Zimbra is upgraded. The change must be re-applied after an upgrade!

The zimbra server needs to be restarted to apply the changes:

```bash
sudo -u zimbra -- /opt/zimbra/bin/zmcontrol restart
```

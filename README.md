nix-bitcoin
===

Nix packages and nixos modules with profiles for easily installing Bitcoin nodes and higher layer protocols.
This is a work in progress - don't expect it to be bug free or secure.

The 'full' profile right now sets up a Bitcoin Core node and c-lightning, accessable with a smartphone using spark-wallet.
A simple webpage shows the lightning nodeid and links to nanopos allowing to receive donations.
It also includes liquid-daemon.
Outbound peer-to-peer traffic is forced through Tor and listening services are bound to onion addresses.

A demo installation is running at [http://6tr4dg3f2oa7slotdjp4syvnzzcry2lqqlcvqkfxdavxo6jsuxwqpxad.onion](http://6tr4dg3f2oa7slotdjp4syvnzzcry2lqqlcvqkfxdavxo6jsuxwqpxad.onion).
The following screen cast shows how a fresh deployment of the full profile.

<p align="center">
  <a href="https://asciinema.org/a/223630/?speed=2&autoplay=1"><img src="https://asciinema.org/a/223630.png" height="500"></a>
</p>



The goal is too make it easy to deploy a reasonably secure Bitcoin node with a usable wallet.
It should allow managing bitcoin (the currency) effectively and providing public infrastructure.
It should be a reproducible and extensible platform applications building on Bitcoin.

Profiles
---
The `nix-bitcoin.nix` module provides the two profiles "minimal" and "all":

* minimal
    * bitcoind (pruned) with outbound connections through Tor and inbound connections through a hidden
      service
    * [clightning](https://github.com/ElementsProject/lightning) with outbound connections through Tor, not listening
    * includes "nodeinfo" script which prints basic info about the node
    * adds non-root user "operator" which has access to bitcoin-cli and lightning-cli
* all
    * adds clightning hidden service
    * [liquid-daemon](https://github.com/blockstream/liquid)
    * [lightning charge](https://github.com/ElementsProject/lightning-charge)
    * [nanopos](https://github.com/ElementsProject/nanopos)
    * adds an index page using nginx to display node information and link to nanopos
    * [spark-wallet](https://github.com/shesek/spark-wallet)
        * Notes: run `nodeinfo` to get its onion address and `systemctl status spark-wallet` to get the access key.
            When entering the onion address on the Android app don't forgot to prepend "http://"
* other
    * [electrs](https://github.com/romanz/electrs) can be enabled by setting `services.electrs.enable` in modules `nix-bitcoin.nix` to `true`

The data directories of the services can be found in `/var/lib` on the deployed machines.

Installing profiles
---
The easiest way is to run `nix-shell` (on a Linux machine) in the nix-bitcoin directory and then create a [NixOps](https://nixos.org/nixops/manual/) deployment with the provided network.nix.
Fix the FIXMEs in configuration.nix and deploy with nixops in nix-shell.
See below for a detailed tutorial.

The profiles require 300 GB (235GB for Bitcoin blockchain + some room) of disk space and 2GB of memory.
Bitcoin Core pruning is not supported at the moment because it's not supported by c-lightning.
It's possible to use pruning but you need to know what you're doing.

Tutorial: install a nix-bitcoin node
---
Get a machine to deploy nix-bitcoin on.
This could be a VirtualBox, a machine that is already running [NixOs](https://nixos.org/nixos/manual/index.html) or a cloud provider.
Have a look at the options in the [NixOps manual](https://nixos.org/nixops/manual/).
There's a tutorial for installing and configuring VirtualBox in the [appendix](#appendix).

The following steps are meant to be run on the machine you deploy from, not the machine you deploy to.

Install Dependencies (Debian 9 stretch)
```
sudo apt-get install curl git gnupg2 dirmngr
```
Install Latest Nix with GPG Verification
```
curl -o install-nix-2.1.3 https://nixos.org/nix/install
curl -o install-nix-2.1.3.sig https://nixos.org/nix/install.sig
gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
gpg2 --verify ./install-nix-2.1.3.sig
sh ./install-nix-2.1.3
. /home/user/.nix-profile/etc/profile.d/nix.sh
```
Clone this project
```
cd
git clone https://github.com/jonasnick/nix-bitcoin
cd ~/nix-bitcoin
```
Setup environment
```
nix-shell
```
Create nixops deployment in nix-shell.
When deploying in a VirtualBox you can use the provided `network-vbox.nix` file (ensure that you've created a host adaptor as explained in the appendix).
```
nixops create network.nix network-vbox.nix -d bitcoin-node
```
Otherwise replace it with a network file as explained in the [NixOps manual](https://nixos.org/nixops/manual/).

Adjust configuration by opening configuration.nix and removing FIXMEs.

Deploy Nixops in nix-shell
```
nixops deploy -d bitcoin-node
```
This will now create a nix-bitcoin node on the target machine.

Nixops automatically creates an ssh key for use with `nixops ssh`. Access `bitcoin-node` through ssh in nix-shell with
```
nixops ssh operator@bitcoin-node
```

Run `nodeinfo` to see your onion addresses for the webindex, spark, etc. if they are included in the profile.

If you change anything in the configuration you can run
```
nixops deploy -d bitcoin-node
```
in the nix-shell again to redeploy the configuration to the node.

Updating
---
Run `git pull` in the nix-bitcoin directory, enter the nix shell with `nix-shell` and redeploy with `nixops deploy -d bitcoin-node`.

FAQ
---
* **Q:** When deploying or trying to SSH into the machine I see
    ```
    bitcoin-node> waiting for SSH...
    Received disconnect from 10.1.1.200 port 22:2: Too many authentication failures
    ```
    * **A:** Somehow ssh-agent and nixops don't play well together. Try killing the ssh-agent.
* **Q:** When deploying or trying to SSH into the machine I see
    ```
    root@xxx.xxx.xxx.xxx: Permission denied (publickey,password,keyboard-interactive).
    ```
    Make sure you don't have something like
    ```
    Host *
        PubkeyAuthentication no
    ```
    in your ssh config.
* **Q:** When deploying to virtualbox for the first time I see
    ```
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: Started Get NixOps SSH Key.
    bitcoin-node> Mar 19 09:22:27 bitcoin-node get-vbox-nixops-client-key-start[2226]: VBoxControl: error: Failed to connect to the guest property service, error VERR_INTERNAL_ERROR
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: get-vbox-nixops-client-key.service: Main process exited, code=exited, status=1/FAILURE
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: get-vbox-nixops-client-key.service: Failed with result 'exit-code'.
    bitcoin-node> error: Traceback (most recent call last):
      File "/nix/store/6zyvpi0q6mvprycadz2dpdqag4742y18-python2.7-nixops-1.6pre0_abcdef/lib/python2.7/site-packages/nixops/deployment.py", line 731, in worker
        raise Exception("unable to activate new configuration")
    Exception: unable to activate new configuration
    ```
    * **A:** This is issue https://github.com/NixOS/nixops/issues/908. The machine needs to be rebooted. You can do that by running `nixops deploy` with the `--force-reboot` flag once.
* **Q:** I'm deploying to virtualbox it's not able to connect anymore.
    * **A:** Maybe the IP address of the box changed. Run `nixops deploy --check` to update nixops with the new IP address. Sometimes you also need to remove the old IP address from `~/.ssh/known_hosts`.
* **Q:** The clightning service is running but when I try to use it (f.e. by running `lightning-cli getinfo` as user operator) all I get is `lightning-cli: Connecting to 'lightning-rpc': Connection refused`.
    * **A:** Check your clightning logs with `journalctl -eu clightning`. Do you see something like `bitcoin-cli getblock ... false` failed? Are you using pruned mode? That means that clightning hasn't seen all the blocks it needs to and it can't get that block because your node is pruned. If you're just setting up a new node you can `systemctl stop clightning` and wipe your `/var/lib/clightning` directory. Otherwise you need to reindex the Bitcoin node.
* **Q:** My disk space is getting low due to nix.
    * **A:** run `nix-collect-garbage -d`

# Appendix
Tutorial: install and configure VirtualBox for nix-bitcoin on Debian 9 Stretch
---
Add virtualbox.list to /etc/apt/sources.list.d
```
deb http://download.virtualbox.org/virtualbox/debian stretch contrib
```
Add Oracle VirtualBox public key
```
wget https://www.virtualbox.org/download/oracle_vbox_2016.asc
gpg2 oracle_vbox_2016.asc
```
Proceed _only_ if fingerprint reads B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF

```
sudo apt-key add oracle_vbox_2016.asc
```
Install virtualbox-5.2
```
sudo apt-get update
sudo apt-get install virtualbox-5.2
```

**IMPORTANT:** Create Host Adapter in VirtualBox
```
Open VirtualBox
File -> Host Network Manager -> Create
This should create a hostadapter named vboxnet0
```
Tutorial: install and configure NixOS for nix-bitcoin on your own hardware
---
## 1. NixOS installation

This is borrowed from the [NixOS manual](https://nixos.org/nixos/manual/index.html#ch-installation). Look there for more information.

1. Obtain latest NixOS. For example:

	```
	wget https://releases.nixos.org/nixos/18.09/nixos-18.09.2257.235487585ed/nixos-graphical-18.09.2257.235487585ed-x86_64-linux.iso
	```

2. Write NixOS iso to install media (USB/CD). For example:

	```
	dd if=nixos-graphical-18.09.2257.235487585ed-x86_64-linux.iso of=/dev/sdX
	```
	Replace /dev/sdX with the correct device name. You can find this using `sudo fdisk -l`

3. Boot the system

	You will have to find out if your hardware uses UEFI or Legacy Boot for the next step.

4. Option 1: Partition and format for UEFI

	```
	parted /dev/sda -- mklabel gpt
	parted /dev/sda -- mkpart primary 512MiB -8GiB
	parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
	parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
	parted /dev/sda -- set 3 boot on
	mkfs.ext4 -L nixos /dev/sda1
	mkswap -L swap /dev/sda2
	mkfs.fat -F 32 -n boot /dev/sda3
	mount /dev/disk/by-label/nixos /mnt
	mkdir -p /mnt/boot
	mount /dev/disk/by-label/boot /mnt/boot
	swapon /dev/sda2
	```

4. Option 2: Partition and format for Legacy Boot (MBR)

	```
	parted /dev/sda -- mklabel msdos
	parted /dev/sda -- mkpart primary 1MiB -8GiB
	parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
	mkfs.ext4 -L nixos /dev/sda1
	mkswap -L swap /dev/sda2
	mount /dev/disk/by-label/nixos /mnt
	swapon /dev/sda2
	```

5. Generate NixOS config

	```
	nixos-generate-config --root /mnt
	nano /mnt/etc/nixos/configuration.nix
	```

	Option 1: Edit NixOS configuration for UEFI

	```
	{ config, pkgs, ... }: {
	  imports = [
	    # Include the results of the hardware scan.
	    ./hardware-configuration.nix
	  ];

	  boot.loader.systemd-boot.enable = true;

	  # Note: setting fileSystems is generally not
	  # necessary, since nixos-generate-config figures them out
	  # automatically in hardware-configuration.nix.
	  #fileSystems."/".device = "/dev/disk/by-label/nixos";
	
	  # Enable the OpenSSH server.
	  services.openssh = {
	    enable = true;
	    permitRootLogin = "yes";
	  };
	}
	```

	Option 2: Edit NixOS configuration for Legacy Boot (MBR)

	```
	{ config, pkgs, ... }: {
	  imports = [
	    # Include the results of the hardware scan.
	    ./hardware-configuration.nix
	  ];
	
	  boot.loader.grub.device = "/dev/sda"; 
	
	  # Note: setting fileSystems is generally not
	  # necessary, since nixos-generate-config figures them out
	  # automatically in hardware-configuration.nix.
	  #fileSystems."/".device = "/dev/disk/by-label/nixos";
	
	  # Enable the OpenSSH server.
	  services.openssh = {
	    enable = true;
	    permitRootLogin = "yes";
	  };
	}
	```

6. Do the installation

	```
	nixos-install
	```
	Set root password
	```
	setting root password...
	Enter new UNIX password: 
	Retype new UNIX password:
	```

7. If everything went well

	```
	reboot
	```

## 2. nix-bitcoin installation

On the machine you are deploying from:

1. Install Dependencies (Debian 9 stretch)

	```
	sudo apt-get install curl git gnupg2 dirmngr
	```

2. Install Latest Nix with GPG Verification

	```
	curl -o install-nix-2.1.3 https://nixos.org/nix/install
	curl -o install-nix-2.1.3.sig https://nixos.org/nix/install.sig
	gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
	gpg2 --verify ./install-nix-2.1.3.sig
	sh ./install-nix-2.1.3
	. /home/user/.nix-profile/etc/profile.d/nix.sh
	```

3. Clone this project

	```
	cd
	git clone https://github.com/jonasnick/nix-bitcoin
	cd ~/nix-bitcoin
	```

4. Create network file

	```
	nano network-nixos.nix
	```

	```
	{
	  bitcoin-node =
	    { config, pkgs, ... }:
	    { deployment.targetHost = 1.2.3.4;
	    };
	}
	```

	Replace 1.2.3.4 with NixOS machine's IP address.

5. Edit `configuration.nix`

	```
	nano configuration.nix
	```

	Uncomment `./hardware-configuration.nix` line by removing #.
	
6. Create `hardware-configuration.nix`

	```
	nano hardware-configuration.nix
	```
	Copy contents of NixOS machine's `hardware-configuration.nix` to file.

7. Add boot option to `hardware-configuration.nix`

	Option 1: Enable systemd boot for UEFI
	```
	boot.loader.grub.device = "/dev/sda";
	```
	Option 2: Set grub device for Legacy Boot (MBR)
	```
	boot.loader.grub.device = "/dev/sda":
	``` 

8. Setup environment
	```
	nix-shell
	```

9. Create nixops deployment in nix-shell.
	```
	nixops create network.nix network-nixos.nix -d bitcoin-node
	```

10. Adjust configuration by opening configuration.nix and removing FIXMEs.

11. Deploy Nixops in nix-shell
	
	```
	nixops deploy -d bitcoin-node
	```
	This will now create a nix-bitcoin node on the target machine.

12. Nixops automatically creates an ssh key for use with `nixops ssh`. Access `bitcoin-node` through ssh in nix-shell with

	```
	nixops ssh operator@bitcoin-node
	```


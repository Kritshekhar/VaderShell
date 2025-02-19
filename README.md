<div align="center" style="font-family: 'Courier New', Courier, monospace; padding: 20px; background-color: black; color: white;">

  <h1 style="font-size: 3em; font-weight: bold; margin-bottom: 20px;">
    🚀 Welcome to the <span style="color: #004d00;">Dark Side - <strong>VaderShell</strong> </span>
  </h1>

  <!---<hr style="width: 60%; border: 1px solid #FFD700; margin: 20px auto;">-->
  
  <p style="font-size: 1.5em; text-transform: uppercase; line-height: 1.5; max-width: 600px; margin: auto; font-weight: bold;">
    <span style="color: #FFD700;">Episode I:</span> <span style="color: #FF0000;">The Rise of VaderShell</span>
  </p>
  <span style="color: #FFD700;">A long time ago, in a galaxy far, far away...</span>
  <p style="font-size: 1.2em; color: #DDD; max-width: 600px; margin: 20px auto; text-align: center;">
    It is a time of technological upheaval. The <strong>VaderShell</strong> has emerged as a powerful automated command center. <br>
    With it, you can connect, control, and dominate all of your infrastructure with one unified force.
    <br><br>
    The Dark Side awaits... Will you answer the call?
  </p>

  ---
</div>


 

## 🌌 Features  

✅ **Centralized SSH Management** – Easily connect to all servers in your network.

✅ **Automatic IP Resolution** – Resolves IPs for servers and VirtualBox VMs.  

✅ **VM Control Panel** – Start, Stop, SSH, and manage VirtualBox instances.  

✅ **Configurable & Extendable** – Define your infrastructure in `source.cfg`.  

✅ **Skywalker Mode** – The **Mother Ship (Admin Server)** has full control over the fleet.  

---

## ⚙️ Configuration  

Before launching **VaderShell**, populate `source.cfg` with your infrastructure details:  

```ini
# List of servers in the format <hostname>:<user>@<hostname>
SERVERS=(
  "server1:user1@server1"
  "server2:user2@server2"
)

# Datacenter Gateway IP for compute nodes
DATACENTER_GW_IP=10.107.30.1

# Base IP of the datacenter compute nodes (e.g., sequential IPs 10.107.30.100+)
DATACENTER_BASE_IP=10.107.30.100

# SSH key for authentication
DATACENTER_GW_SSH_KEY_PATH="/path/to/your/private_key"

# The Mothership (Admin Server) – Master control node
ADMIN_SERVER="<hostname>:<user>@<user>"

# Username for the mother ship server
MOTHERSHIP_USER="skywalker"

# IP address of the mother ship
MOTHERSHIP_IP="10.218.XXX.XXX"

# Destination directory on the mother ship
MOTHERSHIP_DESTINATION="/path/to/death/star/"

# Username for accessing the data center nodes
DATACENTER_USER="skywalker"

# A compute node in the data center
DUMMY_COMPUTE_NODE="10.XX.XX.XXX"

# Destination directory within the data center
DATACENTER_DESTINATION="/home/<users>/${DATACENTER_USER}/<folder>/"

# Local destination directory for files
LOCAL_DESTINATION="/path/to/local/death/star/"
```

## 🛠️ Ussage Guide ⚡

```
 git clone https://github.com/your-repo/vadershell.git
 cd vadershell
 #Configure your servers and infrastructure
 vim source.cfg
 # Run VaderShell
 ./vadershell.sh
```

```sh
__     __        _           ____  _          _ _
\ \   / /_ _  __| | ___ _ __/ ___|| |__   ___| | |
 \ \ / / _` |/ _` |/ _ \ '__\___ \| '_ \ / _ \ | |
  \ V / (_| | (_| |  __/ |   ___) | | | |  __/ | |
   \_/ \__,_|\__,_|\___|_|  |____/|_| |_|\___|_|_|

-------------------------------------
Resolving IP addresses for servers...
-------------------------------------
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Available Virtual Machines:
3.  (VM) VM-1
2.  (VM) VM-2
1.  (VM) VM-3
-----------------------------------------------------------
4.  Server: Server-1 (IP: 10.XXX.XXX.XX)
5.  Server: Server-2 (IP: 10.XXX.XXX.XX)
6.  Server: Server-3 (IP: 10.XXX.XXX.XX)
7.  Datacenter Gateway Node
8.  Datacenter Compute nodes
9.  Mother Ship (Admin)
10.  VM Management
11.  SCP File Transfer
12.  Exit
Enter your menu choice [1-12]:
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
```

## 🛠️ Upcoming Features ⚡  

🚀 **🌑 The Force Grows Stronger:**  

🔹 **Support for QEMU & KVM VMs**  – Expand VaderShell beyond VirtualBox.  
🔹 **More Comprehensive IP Discovery** – Improved detection across networks.  
🔹 **Automated Backup & Restore** – Protect your Empire with scheduled snapshots.  
🔹 **Live VM Migration** – Move VMs across hosts without downtime.  
🔹 **Enhanced Logging & Monitoring** – A Sith Lord must always be aware.  
🔹 **Dark Mode UI for CLI** – Because the Dark Side always looks better.  

> ⚡ *"Once you start down the VaderShell path, forever will it dominate your destiny."*

## ⚡ Troubleshooting  

### 🛑 No IP Found for VM?  
✔️ Ensure the VM is **running**.  
✔️ Check if the network mode is set to **Bridged Adapter**.  
✔️ Use the following command to retrieve the IP:  
   ```sh
   VBoxManage guestproperty get <VM_NAME> "/VirtualBox/GuestInfo/Net/0/V4/IP"
   ```
✔️ If no IP is found, try checking the ARP table: ```arp -a | grep -i "<VM_MAC_ADDRESS>"```

> ⚡ "Patience, young Padawan. Troubleshooting is the path to mastery."


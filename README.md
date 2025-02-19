<div align="center" style="font-family: Arial, sans-serif; padding: 20px;">

  <h1 style="color: #008000; font-size: 2.5em; font-weight: bold; margin-bottom: 10px;">
    <!--☁️ Welcome to <span style="color: #004d00;">VaderShell</span> ☁️-->
    🚀 Welcome to the <span style="color: #004d00;">Dark Side - <strong>VaderShell</strong> </span>
  </h1>

  <hr style="width: 60%; border: 1px solid #008000; margin: 20px auto;">

  <p style="font-size: 1.2em; color: #333; max-width: 600px;">
    A powerful, automated <strong>VaderShell</strong>! command center to connect, control, and operate on all your infrastructure in one place. 
  </p>

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
SSH_KEY_PATH="/path/to/your/private_key.pem"

# The Mothership (Admin Server) – Master control node
ADMIN_SERVER="vader-mothership"
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


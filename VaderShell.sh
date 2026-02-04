#!/bin/bash

# Load configuration file
source config.cfg

# Detect operating system
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Linux*)     OS="Linux";;
    Darwin*)    OS="macOS";;
    *)          OS="Unknown";;
esac

# ===================== Logging toggle (drop-in) =====================
# Assumes config.cfg already sourced above.
: "${VADERSHELL_LOG_ENABLED:=1}"
: "${VADERSHELL_LOG_MODE:=tee}"
: "${VADERSHELL_LOG_DIR:=$HOME/.vadershell/logs}"
: "${VADERSHELL_LOG_FILE:=}"
: "${VADERSHELL_TRACE:=0}"

if [[ "$VADERSHELL_LOG_ENABLED" == "1" ]]; then
  mkdir -p "$VADERSHELL_LOG_DIR"
  SCRIPT_NAME="$(basename "$0")"
  START_TS="$(date +"%Y%m%d-%H%M%S")"
  if [[ -z "$VADERSHELL_LOG_FILE" ]]; then
    VADERSHELL_LOG_FILE="$VADERSHELL_LOG_DIR/${SCRIPT_NAME%.*}_${START_TS}.log"
  else
    mkdir -p "$(dirname "$VADERSHELL_LOG_FILE")"
  fi

  case "$VADERSHELL_LOG_MODE" in
    tee)
      exec > >(tee -a "$VADERSHELL_LOG_FILE") 2>&1
      ;;
    ts-file)
      # Console: raw; File: timestamped (pure bash)
      exec > >(tee >(bash -c '
          f="$1"
          while IFS= read -r line; do
            printf "[%(%Y-%m-%d %H:%M:%S)T] %s\n" -1 "$line"
          done >> "$f"
        ' _ "$VADERSHELL_LOG_FILE")) 2>&1
      ;;
    ts-both)
      # Console + File: timestamped (⚠ single-line prompts may appear late on console)
      exec > >(bash -c '
          f="$1"
          while IFS= read -r line; do
            printf "[%(%Y-%m-%d %H:%M:%S)T] %s\n" -1 "$line" | tee -a "$f"
          done
        ' _ "$VADERSHELL_LOG_FILE") 2>&1
      ;;
    none|*)
      :
      ;;
  esac

  echo "[INFO] Detected OS: $OS"
  echo "[INFO] Log enabled: $VADERSHELL_LOG_MODE -> $VADERSHELL_LOG_FILE"

  if [[ "$VADERSHELL_TRACE" == "1" ]]; then
    export PS4='+ $(date "+%Y-%m-%d %H:%M:%S") ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '
    set -x
  fi
fi
# =================== End logging toggle block ======================


declare -A vm_list
declare -i total_vms=0
declare -i total_servers=${#SERVERS[@]}

# Dynamically fetch available VMs
fetch_vm_list() {
    vm_list=()
    total_vms=0
    index=1
    while read -r line; do
        vm_name=$(echo "$line" | awk -F '"' '{print $2}')
        vm_list[$index]="$vm_name"
        ((index++))
    done < <(VBoxManage list vms)
    total_vms=${#vm_list[@]}
}

# Fetch IP addresses of servers
fetch_server_ips() {
    echo "Resolving IP addresses for servers..."
    echo "-------------------------------------"

    for i in "${!SERVERS[@]}"; do
        IFS=":" read -r name ssh_info <<< "${SERVERS[i]}"

        # Use 'host' to get the IP, fallback to 'nslookup' if needed
        ip_address=$(host "$name" | awk '/has address/ {print $4}')
        if [ -z "$ip_address" ]; then
            ip_address=$(nslookup "$name" 2>/dev/null | awk '/Address: / {print $2}' | tail -n1)
        fi

        if [ -n "$ip_address" ]; then
            SERVER_IPS[$i]="$ip_address"
        else
            SERVER_IPS[$i]="Not Found"
        fi
    done
}

# Connect to C4-Cluster Node
c4_node() {
    read -p "Enter SSH user: " username
    read -p "Enter Node ID: " device_id
    local ip_suffix=$((100 + device_id - 1))
    local ssh_command="sudo ssh -tt \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -o TCPKeepAlive=yes \
        -i \"$DATACENTER_GW_SSH_KEY_PATH\" krit@$DATACENTER_GW_IP \
        \"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -o TCPKeepAlive=yes \
        $username@${DATACENTER_BASE_IP}${ip_suffix}\""

    eval "$ssh_command"
}

# VM Management Menu
vm_management() {
    local vm_name=""

    while true; do
        fetch_vm_list

        echo "++++++++++++++ VM MANAGEMENT MENU ++++++++++++++++"
        for index in "${!vm_list[@]}"; do
            echo "$index - Manage VM: ${vm_list[$index]}"
        done
        echo "---------------------------------------------------"
        echo "$((total_vms+1)). Exit"
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
        read choice

        if [[ $choice -ge 1 && $choice -le $total_vms ]]; then
            vm_name="${vm_list[$choice]}"
            echo "Managing VM: $vm_name"
            vm_operations "$vm_name"
        elif [[ $choice -eq $((total_vms+1)) ]]; then
            echo "Exiting VM management."
            return
        else
            echo "Invalid choice, please try again."
        fi
    done
}

# Function to get the IP of a VirtualBox VM
get_vm_ip() {
    local vm_name="$1"
    local vm_ip=""
    local vm_mac=""

    #echo "DEBUG: Fetching IP for VM: $vm_name"

    # Try getting the IP from guestproperty (VirtualBox Guest Additions required)
    vm_ip=$(VBoxManage guestproperty get "$vm_name" "/VirtualBox/GuestInfo/Net/0/V4/IP" | awk -F: '{print $2}' | tr -d ' ')

    if [[ -n "$vm_ip" && "$vm_ip" != "No value set!" ]]; then
        #echo "DEBUG: IP from guestproperty -> $vm_ip"
        echo "$vm_ip"
        return
    fi

    # Check additional network interfaces (Net/1, Net/2 in case Net/0 is not used)
    for i in {1..3}; do
        vm_ip=$(VBoxManage guestproperty get "$vm_name" "/VirtualBox/GuestInfo/Net/$i/V4/IP" | awk -F: '{print $2}' | tr -d ' ')
        if [[ -n "$vm_ip" && "$vm_ip" != "No value set!" ]]; then
            #echo "DEBUG: IP from guestproperty (Net/$i) -> $vm_ip"
            echo "$vm_ip"
            return
        fi
    done

    # Try getting the IP from showvminfo
    vm_ip=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "GuestIPAddress=" | cut -d'"' -f2)

    if [[ -n "$vm_ip" && "$vm_ip" != "No value set!" ]]; then
        #echo "DEBUG: IP from showvminfo -> $vm_ip"
        echo "$vm_ip"
        return
    fi

    # Get VM MAC address (formatted correctly for ARP lookup)
    vm_mac=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "macaddress1=" | cut -d'"' -f2 | sed 's/\(..\)/\1:/g; s/:$//')
    #echo "DEBUG: VM MAC Address -> $vm_mac"

    # Try checking ARP table using formatted MAC address
    vm_ip=$(arp -a | grep -i "$vm_mac" | awk '{print $2}' | tr -d '()')

    if [[ -n "$vm_ip" ]]; then
        #echo "DEBUG: IP from ARP table -> $vm_ip"
        echo "$vm_ip"
        return
    fi

    # Try checking DHCP leases (if VM is using NAT)
    vm_ip_list=$(VBoxManage list dhcpservers | grep -Eo '10\.[0-9]+\.[0-9]+\.[0-9]+')
    for ip in $vm_ip_list; do
        if ping -c 1 -W 1 "$ip" &>/dev/null; then
            vm_ip="$ip"
            #echo "DEBUG: Found active IP via ping -> $vm_ip"
            break
        fi
    done

    # Final check
    if [[ -n "$vm_ip" ]]; then
        #echo "DEBUG: Selected IP -> $vm_ip"
        echo "$vm_ip"
    #else
        #echo "DEBUG: No IP found for VM $vm_name"
        #echo "No IP Found"
        #pass
    fi
}

# Function to transfer files via SCP
scp_file_transfer() {
    source config.cfg  # Load configuration variables

    echo "Select source:"
    echo "1) Datacenter Node"
    echo "2) Local Server"
    read -p "Enter choice (1 or 2): " choice

    if [ "$choice" -eq 1 ]; then
        echo "Transferring from Datacenter Node..."

        read -p "Enter target file: " target_file
        read -p "Enter destination filename: " dest_filename

        echo " ++++++++++++++++++ SCP File Transfer ++++++++++++++++++"
        echo " - Target file: $target_file"
        echo " - Destination file name: $dest_filename"
        echo "----------------------------------------------------------"

        ssh_cmd="sudo ssh ${MOTHERSHIP_USER}@${MOTHERSHIP_IP} \"ssh -tt -i ${DATACENTER_GW_SSH_KEY_PATH} ${DATACENTER_USER}@${DATACENTER_GW_IP} \\\"scp -r ${DATACENTER_USER}@${DUMMY_COMPUTE_NODE}:${target_file} ${DATACENTER_DESTINATION}${dest_filename}\\\"\""

        echo $ssh_cmd
        eval "$ssh_cmd"

        echo "+++++++++++ File copied to the Gateway node +++++++++++++"

        ssh_cmd="sudo ssh ${MOTHERSHIP_USER}@${MOTHERSHIP_IP} \"scp -r -i ${DATACENTER_GW_SSH_KEY_PATH} ${DATACENTER_USER}@${DATACENTER_GW_IP}:${DATACENTER_DESTINATION}${dest_filename} ${MOTHERSHIP_DESTINATION}${dest_filename}\""
        echo $ssh_cmd
        eval "$ssh_cmd"

        echo "+++++++++++ File copied to the Mother ship +++++++++++++"

    elif [ "$choice" -eq 2 ]; then
        echo "Transferring from Local Server..."

		echo "Select server to transfer file from:"
		for i in "${!SERVER_IPS[@]}"; do
			echo "$((i+1))) ${SERVERS[i]} - IP: ${SERVER_IPS[i]}"
		done

		read -p "Enter choice (1 to ${#SERVERS[@]}): " server_choice
		selected_server_ip=${SERVER_IPS[$((server_choice-1))]}

		if [ "$selected_server_ip" == "Not Found" ]; then
            echo "Error: Selected server IP not found. Exiting."
            return 1
        fi

        # Extract the username from the selected server (SERVERS array format is "hostname:username@hostname")
        selected_server_info=${SERVERS[$((server_choice-1))]}
        selected_server_user=$(echo "$selected_server_info" | cut -d ':' -f2 | cut -d '@' -f1)

        echo "Transferring from Server IP: $selected_server_ip with user: $selected_server_user"

        read -p "Enter target file: " target_file
        read -p "Enter destination filename: " dest_filename

        echo " ++++++++++++++++++ SCP File Transfer ++++++++++++++++++"
        echo " - Target file: $target_file"
        echo " - Destination file name: $dest_filename"
        echo "----------------------------------------------------------"

        ssh_cmd="sudo scp -r ${selected_server_user}@${selected_server_ip}:${target_file} ${MOTHERSHIP_DESTINATION}${dest_filename}"
        echo $ssh_cmd
        eval "$ssh_cmd"

        echo "+++++++++++ File copied to the Mother ship +++++++++++++"
    else
        echo "Invalid choice! Exiting."
        return 1
    fi

    ssh_cmd="sudo scp -r ${MOTHERSHIP_USER}@${MOTHERSHIP_IP}:${MOTHERSHIP_DESTINATION}${dest_filename} ${LOCAL_DESTINATION}${dest_filename}"
    echo $ssh_cmd
    eval "$ssh_cmd"

    echo "+++++++++++ File copied to the localhost +++++++++++++"
}

# VM Operations (Start, Stop, Status, IP, SSH)
vm_operations() {
    local vm_name="$1"

    while true; do
        echo "++++++++++++++ VM OPERATIONS MENU ($vm_name) ++++++++++++++++"
        echo "1 - Start $vm_name"
        echo "2 - Stop $vm_name"
        echo "3 - Check Status of $vm_name"
        echo "4 - Get IP of $vm_name"
        echo "5 - SSH into $vm_name"
        echo "6 - Back to VM Management Menu"
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
        read -p "Enter your choice: " choice

        case $choice in
            1) VBoxManage startvm "$vm_name" --type headless ;;
            2) VBoxManage controlvm "$vm_name" poweroff --type headless ;;
            3) VBoxManage showvminfo "$vm_name" | grep "State:" ;;
            4)
				vm_ip=$(get_vm_ip "$vm_name")
                if [ -z "$vm_ip" ]; then
                    echo "Could not retrieve IP. Try using the hostname: $vm_name"
                else
                    echo "IP Address of VM $vm_name: $vm_ip"
                fi
                ;;
            5)
				vm_ip=$(get_vm_ip "$vm_name")
                read -p "Enter SSH username: " ssh_user
                read -p "Enter hostname: " ssh_hostname
                echo "IP Address of VM $vm_name: $vm_ip"

                if [ -n "$vm_ip" ] && [ "$vm_ip" != "No value set!" ]; then
                    echo "Attempting SSH using IP: $vm_ip"
                    ssh "$ssh_user@$vm_ip"
                else
                    echo "IP not available, trying to SSH using hostname: $ssh_hostname"
                    ssh "$ssh_user@$ssh_hostname"
                fi
                ;;
            6) return ;;
            *) echo "Invalid choice, try again." ;;
        esac
    done
}

# Main Menu
main_menu() {
    while true; do
        figlet VaderShell
        echo "-------------------------------------"

        fetch_vm_list  # Refresh VM list
        fetch_server_ips  # Resolve IPs for servers

        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo "Available Virtual Machines:"
        for index in "${!vm_list[@]}"; do
            echo "$index.  (VM) ${vm_list[$index]}"
        done

        # Servers start after the last VM index
        server_start=$((total_vms + 1))
        echo "-----------------------------------------------------------"

        for ((i = 0; i < total_servers; i++)); do
            server_index=$((server_start + i))
            IFS=":" read -r name ssh_info <<< "${SERVERS[i]}"
            echo "$server_index.  Server: $name (IP: ${SERVER_IPS[$i]})"
        done

        gateway_index=$((server_start + total_servers))
        c4_index=$((gateway_index + 1))
        admin_index=$((c4_index + 1))
        vm_manage_index=$((admin_index + 1))
        scp_index=$((vm_manage_index + 1))
        exit_index=$((scp_index + 1))

        echo "$gateway_index.  Datacenter Gateway Node"
        echo "$c4_index.  Datacenter Compute nodes"
        echo "$admin_index.  Mother Ship (Admin)"
        echo "$vm_manage_index.  VM Management"
        echo "$scp_index.  SCP File Transfer"
        echo "$exit_index.  Exit"
        echo "Enter your menu choice [1-$exit_index]: "
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

        read choice

        if [[ $choice -ge 1 && $choice -le $total_vms ]]; then
            echo "You have selected VM: ${vm_list[$choice]}"
            sudo ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${vm_list[$choice]}@10.218.XXX.XXX"

        elif [[ $choice -ge $server_start && $choice -lt $gateway_index ]]; then
            server_choice_index=$((choice - server_start))
            selected_server="${SERVERS[$server_choice_index]}"
            IFS=":" read -r name ssh_info <<< "$selected_server"
            echo "You have selected the Server: $name (IP: ${SERVER_IPS[$server_choice_index]})"
            sudo ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $ssh_info

        elif [[ $choice -eq $gateway_index ]]; then
            echo "You have selected the Gateway Node"
            sudo ssh -tt -i $DATACENTER_GW_SSH_KEY_PATH krit@$DATACENTER_GW_IP

        elif [[ $choice -eq $c4_index ]]; then
            echo "You are connecting to Datacenter node"
            c4_node

        elif [[ $choice -eq $admin_index ]]; then
            IFS=":" read -r name ssh_info <<< "$ADMIN_SERVER"
            echo "You have selected the $name (Mother Ship)"
            sudo ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $ssh_info

        elif [[ $choice -eq $vm_manage_index ]]; then
            vm_management

        elif [[ $choice -eq $scp_index ]]; then
            scp_file_transfer

        elif [[ $choice -eq $exit_index ]]; then
            echo "Quitting ..."
            exit

        else
            echo "Invalid option"
        fi
        echo "+++++ Thank you for using this service!! +++++"
    done
}

main_menu


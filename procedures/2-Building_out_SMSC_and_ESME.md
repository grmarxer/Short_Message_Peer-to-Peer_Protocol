( Previous Step: [Configuring BIG-IP as a SMPPv3.4 Message Routing Proxy](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/procedures/1-Configure_BIG-IP_message_routing_proxy.md) )  

### Summary  

In this step you will perform the following:

1.  Build your Ubuntu VM's that will serve as the ESME and SMSC Host servers  
2.  Configure the SMSC host server and load the necessary libraries  
3.  Configure the EMSE host server and load the necessary libraries

<br/>   

### Preparing the Ubuntu Server

1. Create two Ubuntu VM's using v16.04 to act as the EMSE host and the SMSC host.  The SMSC host server should have a minimum of three NICs (mgmt, smsc-net1, and smsc-net2).  The ESME host server should have a minimum of two NICs (mgmt and esme-net1)

2. Make sure you are running Ubuntu 16.04  
```lsb_release -a```

3. Update Ubuntu  
```sudo apt-get update -y```  
```sudo apt-get upgrade -y```  
```sudo reboot```  

4. Disable firewall ubuntu  
```sudo ufw disable```  
    ```
    @smsc:~$ sudo ufw status
    Status: inactive
    ```  

5. selinux is not installed by default
```sestatus``` should fail  

6. NTP installed by default -- Verify NTP is in sync  
```timedatectl```  
    ```diff
    @smsc:~$ timedatectl
        Local time: Thu 2020-08-13 10:24:39 PDT
    Universal time: Thu 2020-08-13 17:24:39 UTC
            RTC time: Thu 2020-08-13 17:24:39
        Time zone: America/Los_Angeles (PDT, -0700)
    Network time on: yes
    -NTP synchronized: yes
    RTC in local TZ: no
    ```  



7.  The SMPP library that we will use is built in the `go` language.  We need to install `go` v1.14.4  
    ```
    cd /tmp
    ```  
    ```
    wget https://golang.org/dl/go1.14.4.linux-amd64.tar.gz
    ```  
    ```
    sudo tar xzvf go1.14.4.linux-amd64.tar.gz -C /usr/local
    ```  
8. Modify the user profile to add the `GOPATH`  
    ```
    vi $HOME/.profile
    ```  
    Append the following to the end of the file  
    ```
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    ```  
9.  Source the modified user profile  
    ```
    source ~/.profile
    ```  
10.  Verify the installed `go` version is correct  

        ```
        @SMSC-Host:~$ go version
        go version go1.14.4 linux/amd64
        ```  

11.  Download the necessary libraries and repositories from `git` using `go`  
        ```
        go get github.com/gdamore/tcell
        ```  
        ```
        go get github.com/rivo/tview
        ```  
        ```
        go get github.com/blorticus/smpp-go
        ```  
        ```
        go get github.com/blorticus/smppth
        ```  
12.  Use this procedure to build out and use the __SMPP Test harness__  --  https://github.com/blorticus/smpp-terminal-test-harness     

        In order to build this application:  

        ```
        mkdir ~/git
        cd ~/git
        git clone https://github.com/blorticus/smpp-terminal-test-harness.git
        cd smpp-teerminal-test-harness
        go get -u github.com/blorticus/smpp github.com/blorticus/tpcli github.com/blorticus/smppth
        go build -o smpp-terminal-test-harness .
        ```  

        To run the executable:  
        
        ```
        ./smpp-terminal-test-harness run esmes|smscs /path/to/config.yaml
        ```  



<br/>  

### Configuring the SMSC Host server  

1.  Configure the `/etc/network/interfaces` file to match this environment; ens192 will be used for `smsc-net1` and ens224 will be used for `smsc-net2`  

    __Note:__  We are using secondary IP addresses for the SMSC Simulated servers.  We will bind the Simulated SMSC servers to the secondary IP addresses.  

    ```
    @smsc-host:~$ cat /etc/network/interfaces
    # This file describes the network interfaces available on your system
    # and how to activate them. For more information, see interfaces(5).

    source /etc/network/interfaces.d/*

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    # Interface ens160 is the server's management interface
    auto ens160
    iface ens160 inet static
    address 192.168.2.53
    netmask 255.255.255.0
    gateway 192.168.2.1
    dns-nameservers 8.8.8.8

    auto ens192
    iface ens192 inet static
    address 10.1.20.49
    netmask 255.255.255.0

    auto ens192:1
    iface ens192:1 inet static
    address 10.1.20.50
    netmask 255.255.255.0

    auto ens192:2
    iface ens192:2 inet static
    address 10.1.20.55
    netmask 255.255.255.0

    auto ens224
    iface ens224 inet static
    address 10.1.30.49
    netmask 255.255.255.0

    auto ens224:1
    iface ens224:1 inet static
    address 10.1.30.50
    netmask 255.255.255.0

    auto ens224:2
    iface ens224:2 inet static
    address 10.1.30.55
    netmask 255.255.255.0
    ```  
    ```
    sudo systemctl restart networking
    ```  
2.  Create the `smscs.yaml` file that will be used to activate the SMSC handlers with the following content [Link to smscs.yaml file](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/yaml_files/smscs.yaml).  
    ```
    vi $HOME/smscs.yaml
    ```  


<br/>  

### Configuring RCS ESME clients  

1.  Configure the `/etc/network/interfaces` file to match this environment; ens192 will be used for `esme-net1`  

    __Note:__  We are using secondary IP addresses for the SMSC Simulated servers.  We will bind the Simulated SMSC servers to the secondary IP addresses.  

    ```
    @esme-host:~$ cat /etc/network/interfaces
    # This file describes the network interfaces available on your system
    # and how to activate them. For more information, see interfaces(5).

    source /etc/network/interfaces.d/*

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    # Interface ens160 is the server's management interface
    auto ens160
    iface ens160 inet static
    address 192.168.2.54
    netmask 255.255.255.0
    gateway 192.168.2.1
    dns-nameservers 8.8.8.8

    auto ens192
    iface ens192 inet static
    address 10.1.50.99
    netmask 255.255.255.0
    post-up route add -net 10.1.20.0 netmask 255.255.255.0 gw 10.1.50.254
    post-up route add -net 10.1.30.0 netmask 255.255.255.0 gw 10.1.50.254

    auto ens192:1
    iface ens192:1 inet static
    address 10.1.50.100
    netmask 255.255.255.0

    auto ens192:2
    iface ens192:2 inet static
    address 10.1.50.105
    netmask 255.255.255.0

    auto ens192:3
    iface ens192:3 inet static
    address 10.1.50.110
    netmask 255.255.255.0

    auto ens192:4
    iface ens192:4 inet static
    address 10.1.50.115
    netmask 255.255.255.0
    ```  
    ```
    sudo systemctl restart networking
    ```  

2.  Create the `esme-bind-to-bigip-vip.yaml` file that will be used to activate the ESME handlers and bind two BIG-IP VIPs, vs-smpp-toward-smsc-cluster01 and vs-smpp-toward-smsc-cluster02.  [Link to esme-bind-to-bigip-vip.yaml file](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/yaml_files/esme-bind-to-bigip-vip.yaml)  
        
    ```
    vi $HOME/esme-bind-to-bigip-vip.yaml
    ```  
    



<br/>   

### Next Step  

[Validating ESME and SMSC traffic flows with smppth](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/procedures/3-Validating_traffic_flows_with_smppth.md)
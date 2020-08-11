( Previous Step: [Building out the SMSC and EMSE Servers](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/procedures/1-Building_out_SMSC_and_ESME.md) )  

### Summary  


<br/>   

### Configure the BIG-IP to Support SMPP v3.4 Message Routing Proxy  

1.  Configure the BIG-IP vlans and self-ip's  
    ```
    tmsh create net vlan esme-net1 interfaces add { 1.1 } mtu 1500
    tmsh create net vlan smsc-net1 interfaces add { 1.2 } mtu 1500
    tmsh create net vlan smsc-net2 interfaces add { 1.3 } mtu 1500
    tmsh create net self esme-net1 address 10.1.50.254/24 vlan esme-net1 allow-service default
    tmsh create net self smsc-net1 address 10.1.20.254/24 vlan smsc-net1 allow-service default
    tmsh create net self smsc-net2 address 10.1.30.254/24 vlan smsc-net2 allow-service default
    ```  
2.  Create the BIG-IP SNAT pools  
    ```
    tmsh create ltm snatpool snatpool-smsc-facing-sources-net1 members replace-all-with { 10.1.20.250 }
    tmsh create ltm snatpool snatpool-smsc-facing-sources-net2 members replace-all-with { 10.1.30.250 }
    ```  
3. Create the BIG-IP datagroups  
    ```
    tmsh create ltm data-group  internal smpp-config-elements { records add { asserted-system-type { data bigip }  bigip-system-id { data bigip01 } bigip-system-id-password { data test } } type string }
    tmsh create ltm data-group internal smpp-shortcode-routing { records add { 11211 { data 10.1.50.100%0:2775,10.1.50.105%0:2775 } 33433 { data 10.1.50.110%0:2775,10.1.50.115%0:2775 } default { data 10.1.50.100%0:2775,10.1.50.105%0:2775 } } type string }
    ```  
4.  Create the following SMPP iRules using the `load sys config from-terminal merge` command.  __DO NOT__ forget the merge or you will be sorry.  Although only a single iRule will be attached to the VIP, all of the following iRules are required.  They will be called from the `smpp-clientside` iRule.  

        ```
        tmsh
        ```
        ```
        load sys config from-terminal merge
        ```  

       - Create the `config-variables-smsc-cluster-01` iRule with the following contents [config-variables-smsc-cluster-01](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/iRules/config-variables-smsc-cluster-01.tcl)


        - Create the `config-variables-smsc-cluster-02` iRule with the following contents [config-variables-smsc-cluster-02](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/iRules/config-variables-smsc-cluster-02.tcl)  


        - Create the `logging` iRule with the following contents [logging](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/iRules/logging.tcl)  


        - Create the `smpp-clientside` iRule with the following contents [smpp-clientside](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/iRules/smpp-clientside.tcl)  


        - Create the `smpp-serverside` iRule with the following contents [smpp-serverside](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/iRules/smpp-serverside.tcl)  
  

5.  Create the SMSC Pools  
    ```
    tmsh create ltm pool pool-smscs-cluster01 { members add { cluster01-smsc01:smpp { address 10.1.20.50 } cluster01-smsc02:smpp { address 10.1.20.55  } } monitor gateway_icmp }
    tmsh create ltm pool pool-smscs-cluster02 { members add { cluster02-smsc01:smpp { address 10.1.30.50 } cluster02-smsc02:smpp { address 10.1.30.55 } } monitor gateway_icmp }
    ```  
6.  Create the generic MRF SMPP protocol  
    ```
    tmsh create ltm message-routing generic protocol smpp description "Short Message Peer-to-Peer" no-response yes disable-parser yes
    ```  
7.  Create the generic MRF transport-config  
    ```
    tmsh create ltm message-routing generic transport-config tc-toward-smscs-cluster01 profiles replace-all-with { smpp f5-tcp-progressive } source-address-translation { type snat pool snatpool-smsc-facing-sources-net1 } rules { smpp-serverside config-variables-smsc-cluster-01 } 
    tmsh create ltm message-routing generic transport-config tc-toward-smscs-cluster02 profiles replace-all-with { smpp f5-tcp-progressive } source-address-translation { type snat pool snatpool-smsc-facing-sources-net2 } rules { smpp-serverside config-variables-smsc-cluster-02 }
    ```  
8.  Create the generic MRF peers  
    ```
    tmsh create ltm message-routing generic peer peer-smsc-cluster01 pool pool-smscs-cluster01 transport-config tc-toward-smscs-cluster01
    tmsh create ltm message-routing generic peer peer-smsc-cluster02 pool pool-smscs-cluster02 transport-config tc-toward-smscs-cluster02
    ```  
9. Create the generic MRF routes  
    ```
    tmsh create ltm message-routing generic route route-smsc-cluster01 peers { peer-smsc-cluster01 }
    tmsh create ltm message-routing generic route route-smsc-cluster02 peers { peer-smsc-cluster02 }
    ```  
10. Create the generic MRF router  
    ```
    tmsh create ltm message-routing generic router router-toward-smsc-cluster01 routes replace-all-with { route-smsc-cluster01 }
    tmsh create ltm message-routing generic router router-toward-smsc-cluster02 routes replace-all-with { route-smsc-cluster02 }
    ```  

11.  Create the SMPP Virtual Servers  
        ```
        tmsh create ltm virtual vs-smpp-toward-smsc-cluster01 profiles replace-all-with { smpp router-toward-smsc-cluster01 f5-tcp-progressive } destination 10.1.50.20:2775 rules { smpp-clientside }
        tmsh create ltm virtual vs-smpp-toward-smsc-cluster02 profiles replace-all-with { smpp router-toward-smsc-cluster02 f5-tcp-progressive } destination 10.1.50.30:2775 rules { smpp-clientside }
        ```  
12.  Configure the generic MRF peers to auto-initialize  
        ```
        tmsh modify ltm message-routing generic peer peer-smsc-cluster02 auto-initialization enabled auto-initialization-interval 2000
        tmsh modify ltm message-routing generic peer peer-smsc-cluster01 auto-initialization enabled auto-initialization-interval 2000
        tmsh save sys config
        ```  


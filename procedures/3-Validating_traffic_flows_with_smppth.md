( Previous Step: [Building out the SMSC and EMSE Servers](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/procedures/1-Building_out_SMSC_and_ESME.md) )  

### Summary  


<br/>   

### smppth Overview

As mentioned earlier, this demo utilizes an SMPP test harness called smppth.  It is open-source and is hosted in a github repository.  smppth is designed for building custom test harnesses but provides a default application – smpp-test-harness – which this solution uses.  smpp-test-harness provides a terminal UI.  One instance is run on the smscs host instance and manages all of the SMSC agents.  Another instance is run on the esmes host instance and manages all of the ESME agents.  

In both cases the smppth user-interface looks like the following:  

![smppth test harness](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/smppth-blank-screen.PNG)  


As you can see, there are three boxes: a Command History box, a Command Entry box, and an Events Output box.  Initially, the Command Entry box has focus.  Instructions can be given to the SMPP agents controlled by the associated instance UI by entering text command here, then pressing <enter>.  Any line entered here is appended to the Command History.  Any events involving the controlled agents – or the application itself – generate output in the Events Output box.  Hitting tab cycles focus between the three boxes.  In the Command History Box and the Events box, the arrow keys can be used to scroll backward and forward in the output text in the box.  The Command Entry box supports a subset of readline, including ^a, ^e, ^k, and the up- and down-arrows for command history.  


### Using smppth to Validate traffic flows 

The following is a detailed, step-by-step script for the demonstrating this solution  

1. Start SMSC agent handler (SMSC-Host-Server)

    ```
    cd $GOPATH/src/github.com/blorticus/smppth/apps/smpp-test-harness
    ```  
    ```
    go run . run smscs $HOME/smscs.yaml
    ```  

    This will start the smpp-test-harness UI.  Wait a moment until you see messages in the Event Output Box that shows bind sessions (this happens automatically because the SMSC peers are set to auto-initialization).  

    ![SMSC startup](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/smsc_go_run.PNG)



2. Start ESME agent handler  (ESME-Host-Server)

    ```
    cd $GOPATH/src/github.com/blorticus/smppth/apps/smpp-test-harness
    ```  
    ```
    go run . run esmes $HOME/esme-bind-to-bigip-vip.yaml
    ```   

    Once again, wait until the UI reports that the ESMEs have completed their binds (which happens because the YAML file instructs them to do so):  

    ![EMSE startup](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/esme_go_run.PNG)  

    Together, these demonstrate that the bind function is independent on the two sides (i.e., the ESME-side and the SMSC-side) of the BIG-IP.  

3. Send enquire-link commands  

    On the ESME handler, enter the following command in the `Enter Command>` entry box  
    ```
    rcs01-tp01: send enquire-link to cluster01-vs
    ```  

    In the Event Output box, you should see a notice that the enquire-link was sent and that an enquire-link-resp was received.  

    ![rcs01-tp01: send enquire-link to cluster01-vs](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/rcs01-tp01-send-enquire-link-to-cluster01-vs.PNG)  

    Switch to the SMSC UI and note that the enquire-link does __NOT__ appear there.  

    Send an enquire-link from one of the SMSC agents using the SMSC UI:  

    On the SMSC handler, enter the following command in the `Enter Command>` entry box  
    ```
    cluster01-smsc01: send enquire-link to bigip01
    ```  

    Once again, you should note the enquire-link go out and an enquire-link-resp come back.  If you look at the ESME UI, there is no corresponding enquire-link received.

    This demonstrates that enquire-links are terminated on the BIG-IP.


4.  Send submit-sm messages from ESMEs to SMSCs  

    Recall that, when an ESME sends a request to the cluster01 Virtual Server, it is delivered to SMSC cluster01, using round-robin on a per-message basis.  

    Send a submit-sm from an ESME to the cluster01 VS, using the ESMEs UI:  

    On the ESME handler, enter the following command in the `Enter Command>` entry box  
    ```
    rcs01-tp01: send submit-sm to cluster01-vs short_message="message 01"
    ```  

    Notice in the Events Output that a submit-sm was sent, and a submit-sm-resp was received.  The test harness automatically inserts the name of the peer that sent the submit-sm-resp in the response message_id field.  The response should have come from either cluster01-smsc01 or cluster01-smsc02, since the request was forwarded to cluster01.

    ![rcs01-tp01-send-submit-sm-to-cluster01-vs-short_message--message-01](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/rcs01-tp01-send-submit-sm-to-cluster01-vs-short_message--message-01.png)  


    Check the SMSC UI.  You should see the submit-sm request come in, and the submit-sm-resp go out:  

    ![smsc-response-to-rcs01-tp01-send-submit-sm-to-cluster01-vs-short_message--message-01](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/smsc-response-to-rcs01-tp01-send-submit-sm-to-cluster01-vs-short_message--message-01.png)  

    Send a second submit-sm on the ESME handler, from a different rcs cluster:  

    ```
    rcs02-tp01: send submit-sm to cluster01-vs short_message="message 02"
    ```  

    ![rcs02-tp01-send-submit-sm-to-cluster01-vs-short_message--message-02](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/rcs02-tp01-send-submit-sm-to-cluster01-vs-short_message--message-02.png)  

    Notice that the response to this submit-sm comes from the other member of cluster01.  Again, check the SMSC UI and validate that the submit-sm arrived, and a submit-sm-resp was sent.  

5. Send messages from SMSC to ESME using short code for routing  

    If an SMSC sets the destination_addr field of a submit-sm, and it matches a short code associated with an rcs cluster (BIG-IP data-group smpp-shortcode-routing), the submit-sm will be load-balanced to the matching rcs cluster, using round robin.  To demonstrate this, from the SMSC UI:  

    On the SMSC handler, enter the following command in the `Enter Command>` entry box  
    ```
    cluster01-smsc01: send submit-sm to bigip01 destination_addr=11211 short_message="message 03"
    ```  

    The response should come back from a member of the cluster rcs01.  From the SMSC side, that should look like this (although the message_id value may be rcs01-tp02, rather than rcs01-tp01, depending on which rcs cluster member to which the request was routed):  

    ![cluster01-smsc01-send-submit-sm-destination_addr--11211-short_message-message-03](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/cluster01-smsc01-send-submit-sm-destination_addr--11211-short_message-message-03.png)  


    And from the ESME, it should look like this:  

    ![response-cluster01-smsc01-send-submit-sm-destination_addr--11211-short_message-message-03](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/response-cluster01-smsc01-send-submit-sm-destination_addr--11211-short_message-message-03.png)  


    Execute the same command again from the SMSC UI:  

    On the SMSC handler, enter the following command in the `Enter Command>` entry box  
    ```
    cluster01-smsc01: send submit-sm to bigip01 destination_addr=11211 short_message="message 03"
    ```  

    You should now see a response from the other rcs cluster member:  


    ![cluster01-smsc01-send-submit-sm-destination_addr--11211-short_message-message-03-number-2](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/cluster01-smsc01-send-submit-sm-destination_addr--11211-short_message-message-03-number-2.png) 

    Try sending a submit-sm to the other short code `33433` that we have configured in the BIG-IP `smpp-shortcode-routing` data-group  

    On the SMSC handler, enter the following command in the `Enter Command>` entry box  
    ```
    cluster01-smsc02: send submit-sm to bigip01 destination_addr=33433 short_message="message 05"
    ```  

    The message to 33433 should elicit a response from a member of the rcs02 cluster  

    ![cluster01-smsc02-send-submit-sm-destination_addr--3433-short_message-message-05](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/cluster01-smsc02-send-submit-sm-destination_addr--3433-short_message-message-05.png)


    This demonstrates proper short code based routing from SMSCs to ESMEs.  
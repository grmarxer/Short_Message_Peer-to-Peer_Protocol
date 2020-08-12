( Previous Step: [Building out the SMSC and EMSE Servers](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/procedures/1-Building_out_SMSC_and_ESME.md) )  

### Summary  


<br/>   

### smppth Overview

As mentioned earlier, this demo utilizes an SMPP test harness called smppth.  It is open-source and is hosted in a github repository.  smppth is designed for building custom test harnesses but provides a default application – smpp-test-harness – which this solution uses.  smpp-test-harness provides a terminal UI.  One instance is run on the smscs host instance and manages all of the SMSC agents.  Another instance is run on the esmes host instance and manages all of the ESME agents.  

In both cases the smppth user-interface looks like the following:  

![smppth test harness](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/smppth-blank-screen.PNG)  


As you can see, there are three boxes: a Command History box, a Command Entry box, and an Events Output box.  Initially, the Command Entry box has focus.  Instructions can be given to the SMPP agents controlled by the associated instance UI by entering text command here, then pressing <enter>.  Any line entered here is appended to the Command History.  Any events involving the controlled agents – or the application itself – generate output in the Events Output box.  Hitting tab cycles focus between the three boxes.  In the Command History Box and the Events box, the arrow keys can be used to scroll backward and forward in the output text in the box.  The Command Entry box supports a subset of readline, including ^a, ^e, ^k, and the up- and down-arrows for command history.  


### Using smppth to Validate traffic flow

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
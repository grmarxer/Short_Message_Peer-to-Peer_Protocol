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

If the ESME clients started and bound to the BIG-IP VIPs correctly you will see the following

![EMSE startup](https://github.com/grmarxer/Short_Message_Peer-to-Peer_Protocol/blob/master/illustrations/esme_go_run.PNG)
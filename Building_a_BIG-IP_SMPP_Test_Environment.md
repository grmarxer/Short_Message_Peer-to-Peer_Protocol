## Building a BIG-IP Short Message Peer-to-Peer Protocol (SMPP) Test / Demo Environment  

### Purpose of this Guide 

This procedure will provide you with step by step instructions for creating a SMPP v3.4 environment (ESME's and SCMS's) and configuring BIG-IP as a SMPP v3.4 Proxy.  In this configuration we will configure four virtual SMSC's running on a single SMSC host and 4 virtual ESME's running on a single EMSE host.  The BIG-IP will use generic MRF and iRules to proxy traffic between ESME's and SMSC's.  The iRule also supports short message code routing from SMSC to EMSE's.  The logic for this solution is completely based on generic MRF and iRules.  If you wish to expand the functionality beyond the scope of what is included here you will have to reconfigure the iRules to support that functionality.

In addition the SMPP v3.4 protocol was not written with proxy server support.  Thus each ESME and SMSC believes it is in a full mesh with one another.  This is what makes using the BIG-IP as a SMPP proxy so attractive yet provides challenges such as error handling.


### and Prerequisites/Requirements  






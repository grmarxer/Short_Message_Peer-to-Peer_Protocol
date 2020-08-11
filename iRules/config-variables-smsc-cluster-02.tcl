ltm rule config-variables-smsc-cluster-02 {
when SERVER_CONNECTED {
        set name_of_virtual_server_facing_this_smsc_cluster "/Common/vs-smpp-toward-smsc-cluster02"
    }
}

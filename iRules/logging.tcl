ltm rule logging {
##
## Simple Message Peer-to-Peer (SMPP) system_type based routing and bind management
##
## @version = 2
## @date = 24 Aug 2019
## @author = Vernon Wells (vwells@f5.com)

when RULE_INIT {
    set static::log_debug 1
    set static::log_trace 1

    array set static::smpp_command_map [list 1 bind_receiver 2 bind_transmitter 3 query_sm 4 submit_sm 5 deliver_sm 6 unbind 7 replace_sm 8 cancel_sm 9 bind_transceiver 11 outbind 21 enquire_link 33 submit_multi 259 data_sm 2147483648 generic_nack 2147483649 bind_receiver_resp 2147483650 bind_transmitter_resp 2147483651 query_sm_resp 2147483652 submit_sm_resp 2147483653 deliver_sm_resp 2147483654 unbind_resp 2147483655 replace_sm_resp 2147483656 cancel_sm_resp 2147483657 bind_transceiver_resp 2147483669 enquire_link_resp 2147483681 submit_multi_resp 2147483906 alert_notification 2147483907 data_sm_resp]
}

proc debug {msg} {
    if { $static::log_debug } {
        if { [clientside] } {
            log local0.debug "(clientside) $msg"
        } else {
            log local0.debug "(serverside) $msg"
        }
    }
}

proc trace {msg} {
    if { $static::log_trace } {
        if { [clientside] } {
            log local0.debug "(clientside) $msg"
        } else {
            log local0.debug "(serverside) $msg"
        }
    }
}


proc smpp_command_id_to_name {command_id} {
    if { [info exists static::smpp_command_map($command_id)] } {
        return $static::smpp_command_map($command_id)
    } else {
        return $command_id
    }
}
}


ltm rule smpp-clientside {
    when RULE_INIT {
    set static::smpp_config_elements_dg "smpp-config-elements"
}

when CLIENT_ACCEPTED {
    set proxy_side "clientside"
    set peer_state "waiting_for_bind"
    set incoming_buf ""

    set local_seq_number 1      ;# 1 is reserved for bind message, so start at 2
    array set seq_rewrite_table [list]

    set peer_name "[IP::client_addr]:[TCP::client_port]"
    set my_vs_or_tc_name [virtual]
    set my_vs_or_tc_type "virtual"

    call logging::debug "peer_name = ($peer_name); my_vs_or_tc_name = ($my_vs_or_tc_name); my_vs_or_tc_type = ($my_vs_or_tc_type)"

    GENERICMESSAGE::peer name $peer_name

    TCP::collect
}

when CLIENT_DATA {
    append incoming_buf [TCP::payload]

    TCP::payload replace 0 [TCP::payload length] ""
    TCP::release
    TCP::collect

    # Need at least 16 octets for a header, and thus, at least 16 octets for a PDU
    if { [string length $incoming_buf] >= 16 } {
        binary scan $incoming_buf IIII command_length command_id command_status sequence_number

        # convert $command_id to its unsigned value
        set command_id [expr { $command_id & 0xffffffff }]

        if { ($command_id & 0x80000000) == 0 } {
            set is_request_msg 1
        } else {
            set is_request_msg 0
        }

        call logging::debug "is_request_msg = ($is_request_msg); command_length = ($command_length); command_id = ($command_id); command_name = ([call logging::smpp_command_id_to_name $command_id]); command_status = ($command_status); sequence_number = ($sequence_number)" 

        if { $command_length > [string length $incoming_buf] } {
            # not enough octets in collected buf for length of next PDU, so its an incomplete PDU
            call logging::debug "Not enough octets yet collected for complete PDU"  
            return
        }

        switch $command_id {
            1 - 2 - 9 {                             ;# bind_* command
                call logging::debug "Received bind_* command"  

                if { $peer_state eq "waiting_for_bind" } {
                    # send bind response
                    set resp_command_id [expr { 0x80000000 | $command_id }]

                    set my_system_id [class lookup "bigip-system-id" $static::smpp_config_elements_dg]

                    # +1 is for null octet after system_id
                    set response_message_length [expr { 16 + [string length $my_system_id] + 1 }]

                    call logging::debug "resp_command_id = ($resp_command_id); resp_command_name = (command_name = ([call logging::smpp_command_id_to_name $resp_command_id])); my_system_id = ($my_system_id)"     
                    call logging::debug "Responding to client with bind response"      

                    TCP::respond [binary format IIIIa*x $response_message_length $resp_command_id 0 $sequence_number $my_system_id]

                    set peer_state "bound"
                }
                else {
                    #send_error_message()
                }
            }

            2147483649 - 2147483650 - 2147483657 {  ;# bind_*_resp command
                log local0. "Received bind resp from peer ($peer_name).  Ignoring."  ;# T=I
            }

            6 {                                     ;# unbind command
                log local0. "Received unbind request from peer ($peer_name).  Sending unbind_resp and closing transport."     ;# T=I
                TCP::respond [binary format IIII 16 0x80000006 0 $sequence_number]
                TCP::close
                return
            }

            2147483654 {                            ;# unbind_resp command
                log local0. "Received unbind response from peer ($peer_name).  Closing transport."     ;# T=I
                TCP::close
            }

            21 {                                    ;# enquire_link command
                call logging::debug "Received enquire_link from peer ($peer_name).  Sending response."    
                TCP::respond [binary format IIII 16 0x80000015 0 $sequence_number]
            }

            2147483669 {                            ;# enquire_link_resp command
                call logging::debug "Received enquire_link response from peer ($peer_name)."
                # ignore the message
            }

            default {
                call logging::debug "Routing message to serverside"
                binary scan $incoming_buf "c$command_length" binary_list
                set message_data [binary format c* $binary_list]
                GENERICMESSAGE::message create 
            }
        }

        # remove current PDU from incoming buffer
        binary scan $incoming_buf "x${command_length}c*" incoming_buf
        set incoming_buf [binary format c* $incoming_buf]
    }
}


when MR_INGRESS {
    set reverse_peer_name $peer_name
    set reverse_vs_or_tc_name $my_vs_or_tc_name
    set reverse_vs_or_tc_type $my_vs_or_tc_type

    MR::store reverse_peer_name reverse_vs_or_tc_name reverse_vs_or_tc_type
}

when MR_FAILED {
    if { [MR::message retry_count] >= [MR::max_retries] } {
        log local0. "Received dynamic-peer message that cannot be delivered after ([MR::max_retries]) retries."  ;# T=I
        MR::message drop
    }
    else {
        log local0. "Message send failed, retrying.  Status is [MR::message status]."
        MR::message nexthop none
        MR::retry
    }
}

when MR_EGRESS {
    MR::restore reverse_peer_name reverse_vs_or_tc_name reverse_vs_or_tc_type
    call logging::debug "Restored Values: reverse_peer_name = ($reverse_peer_name), reverse_vs_or_tc_name = ($reverse_vs_or_tc_name), reverse_vs_or_tc_type = ($reverse_vs_or_tc_type)"
}

when GENERICMESSAGE_INGRESS {
    GENERICMESSAGE::message data $message_data
}

when GENERICMESSAGE_EGRESS {
    binary scan [GENERICMESSAGE::message data] IIII em_command_length em_command_id em_command_status em_sequence_number

    if { ($em_command_id & 0x80000000) == 0 } {
        call logging::debug "GENERICMESSAGE_EGRESS message REQUEST"

        binary scan [GENERICMESSAGE::message data] x16c* em_body
        set rewritten_seq_num [expr { 0xffffffff & [incr local_seq_number] }]

        if { $rewritten_seq_num > 4294967295 } {
            set rewritten_seq_num 2
        }

        call logging::debug "em_command_length = ($em_command_length), em_command_id = ($em_command_id), em_command_name = ([call logging::smpp_command_id_to_name $em_command_id]), em_command_status = ($em_command_status), em_sequence_number = ($em_sequence_number), rewritten_seq_num = ($rewritten_seq_num)"

        call logging::debug "Writing information to sequence rewrite table for ($proxy_side-$rewritten_seq_num)"
        set seq_rewrite_table("$proxy_side-$rewritten_seq_num") [list $em_sequence_number $reverse_peer_name $reverse_vs_or_tc_type $reverse_vs_or_tc_name]

        if { [serverside] and $peer_state ne "bound" } {
            log local0. "Queueing message for delivery once bind is completed"      ;# T=I
            lappend queued_messages [binary format IIIIc* $em_command_length $em_command_id $em_command_status $rewritten_seq_num $em_body]
            GENERICMESSAGE::message drop
        }
        else {
            call logging::debug "Delivering message with altered sequence number ($rewritten_seq_num)"
            TCP::respond [binary format IIIIc* $em_command_length $em_command_id $em_command_status $rewritten_seq_num $em_body]
        }
    }
    else {
        call logging::debug "GENERICMESSAGE_EGRESS message REQUEST, sending directly"
        TCP::respond [GENERICMESSAGE::message data]
    }
}



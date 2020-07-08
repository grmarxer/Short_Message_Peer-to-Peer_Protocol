when RULE_INIT {
    set static::short_code_route_pointer 0
}

proc determine_c_octet_field_length {pdu_var field_start_index max_field_length} {
    upvar $pdu_var smpp_buffer
    binary scan $smpp_buffer "x${field_start_index}c$max_field_length" field_octets
    set field_length 1
    foreach octet $field_octets {
        if { $octet == 0 } {
            return $field_length
        }

        incr field_length
    }

    # PDU is invalidly formatted
    return -1
}

proc extract_destination_addr_from_submit_sm_pdu {pdu_var} {
    upvar $pdu_var smpp_buffer
    set pdu_offset 16
    if { [set field_length [call determine_c_octet_field_length smpp_buffer 16 6]] == -1 } { ;# service_type
        return ""
    }

    incr pdu_offset $field_length
    incr pdu_offset 2 ;# source_addr_ton, source_addr_npi

    if { [set field_length [call determine_c_octet_field_length smpp_buffer $pdu_offset 21]] == -1 } { ;# source_addr
        return ""
    }

    incr pdu_offset $field_length
    incr pdu_offset 2 ;# dest_addr_ton, dest_addr_npi

    if { [set field_length [call determine_c_octet_field_length smpp_buffer $pdu_offset 21]] == -1 } { ;# source_addr
        return ""
    }

    binary scan $smpp_buffer "x${pdu_offset}a$field_length" dest_addr
    return [string range $dest_addr 0 end-1]  ;# remove null
}


when SERVER_CONNECTED {
    set proxy_side "serverside"
    set peer_name "[IP::server_addr]:[TCP::server_port]"
    set my_vs_or_tc_name [lindex [split [MR::transport]] 1]
    set my_vs_or_tc_type "config"

    GENERICMESSAGE::peer name $peer_name

    call logging::debug "peer_name = ($peer_name); my_vs_or_tc_name = ($my_vs_or_tc_name); my_vs_or_tc_type = ($my_vs_or_tc_type)"

    set queued_messages [list]

    set incoming_buf ""
    set local_seq_number 1      ;# 1 is reserved for bind message, so start at 2
    array set seq_rewrite_table [list]

    set route_select_counter 0

    set my_system_id [class lookup "bigip-system-id" $static::smpp_config_elements_dg]
    set password [class lookup "bigip-system-id-password" $static::smpp_config_elements_dg]
    set system_type [class lookup "asserted-system-type" $static::smpp_config_elements_dg]

    set response_cmd_length [expr { 16 + [string length $my_system_id] + 1 + [string length $password] + 1 + [string length $system_type] + 1 + 4 }]

    call logging::debug "peer_name = ($peer_name); system_type = ($system_type), password = ($password), my_system_id = ($my_system_id), response_cmd_length = ($response_cmd_length)"

    call logging::debug "Sending bind_transceiver"
    TCP::respond [binary format IIIIa*xa*xa*xcccc $response_cmd_length 9 0 1 $my_system_id $password $system_type 0x34 0 0 0]

    set peer_state "waiting_for_bind_resp"
    set message_explicit_nexthop ""

    TCP::collect
}


when SERVER_DATA {
    append incoming_buf [TCP::payload]

    TCP::payload replace 0 [TCP::payload length] ""
    TCP::release
    TCP::collect

    # need at least 16 octets for a header, and thus, at least 16 octets for a PDU
    if { [string length $incoming_buf] >= 16 } {
        binary scan $incoming_buf IIII command_length command_id command_status sequence_number

        set command_length [expr { $command_length & 0xffffffff }]

        if { $command_length > [string length $incoming_buf] } {
            # not enough octets in collected buf for length of next PDU, so its and incomplete PDU
            return
        }

        # convert $command_id to its unsigned value
        set command_id [expr { $command_id & 0xffffffff }]

        if { ($command_id & 0x80000000) == 0 } {
            set is_request_msg 1
        } else {
            set is_request_msg 0
        }

        call logging::debug "is_request_msg = ($is_request_msg); command_length = ($command_length), command_id = ($command_id), command_name = ([call logging::smpp_command_id_to_name $command_id]), command_status = ($command_status), sequence_number = ($sequence_number)"

        switch $command_id {
            1 - 2 - 9 {                             ;# bind_* command
                log local0. "Received unexpected bind command from SMSC peer ([IP::server_addr]:[TCP::server_port]).  Ignoring."
            }

            2147483649 - 2147483650 - 2147483657 {  ;# bind_*_resp command
                if { $peer_state eq "waiting_for_bind_resp" } {
                    set peer_state "bound"

                    call logging::debug "Received bind response"
                    foreach m $queued_messages {
                        call logging::debug "Sending queued message"
                        TCP::respond $m
                    }
                }
                #else {
                #    send_error_message()
                #}
            }

            6 {                                     ;# unbind command
                log local0. "Received unbind request from peer ([IP::server_addr]:[TCP::server_port]).  Sending unbind_resp and closing transport."     ;# T=I
                TCP::respond [binary format IIII 16 0x80000006 0 $sequence_number]
                TCP::close
                return
            }

            2147483654 {                            ;# unbind_resp command
                # assume that we sent an unbind command
                TCP::close
            }

            21 {                                    ;# enquire_link command
                call logging::debug "Received enquire_link from peer ([IP::server_addr]:[TCP::server_port]).  Sending response."
                TCP::respond [binary format IIII 16 0x80000015 0 $sequence_number]
            }

            2147483669 {                            ;# enquire_link_resp command
                call logging::debug "Received enquire_link response from peer ([IP::server_addr]:[TCP::server_port])."
                ;# ignore the message
            }

            4 {                                     ;# submit_sm
                call logging::trace "Received submit-sm from peer ([IP::server_addr]:[TCP::server_port])."
                set short_code [call extract_destination_addr_from_submit_sm_pdu incoming_buf]
                call logging::trace "Message has short_code = ($short_code)"

                set short_code_route [class lookup "$short_code" smpp-shortcode-routing]
                call logging::trace "Message with short_code ($short_code) matches route = ($short_code_route)"

                if { $short_code_route eq "" } {
                    log local0.warn "Received SMSC ingress message with short_code = ($short_code).  Dropping because there is no route."
                }
                else {
                    set route_list [split $short_code_route ","]
                    set message_explicit_nexthop [lindex $route_list [expr { [incr static::short_code_route_pointer] % [llength $route_list] }]]
                    call logging::trace "Selected nexthop = ($message_explicit_nexthop)"

                    binary scan $incoming_buf "c$command_length" binary_struct
                    GENERICMESSAGE::message create [binary format c* $binary_struct]
                }
            }

            default {
                call logging::debug "Received message from peer: [call logging::smpp_command_id_to_name $command_id]"
                #GENERICMESSAGE::message create [string range $incoming_buf 0 [expr { $command_length - 1 }]]
                binary scan $incoming_buf "c$command_length" binary_struct
                GENERICMESSAGE::message create [binary format c* $binary_struct]
            }
        }

        # remove current PDU from incoming buffer
        #set incoming_buf [string range $incoming_buf $command_length end]
        binary scan $incoming_buf "x${command_length}c*" incoming_buf
        set incoming_buf [binary format c* $incoming_buf]
    }

}


when GENERICMESSAGE_INGRESS {
    if { !$is_request_msg } {
        call logging::debug "GENERICMESSAGE_INGRESS for response message"

        #binary scan [GENERICMESSAGE::message data] IIIIc* im_command_length im_command_id im_command_status im_sequence_number im_body
        #set im_sequence_number [expr { $im_sequence_number & 0xffffffff }]
        set sequence_number [expr { $sequence_number & 0xffffffff }]

        call logging::debug "command_length = ($command_length), command_id = ($command_id), command_name = ([call logging::smpp_command_id_to_name $command_id]), command_status = ($command_status), sequence_number = ($sequence_number)"

        call logging::debug "Attempting sequence rewrite table lookup for key ($proxy_side-$sequence_number)"
        if { [info exists seq_rewrite_table("$proxy_side-$sequence_number")] } {
            set seq_based_route_info $seq_rewrite_table("$proxy_side-$sequence_number")

            call logging::debug "seq_based_route_info = ($seq_based_route_info)"
            call logging::debug "Altering sequence number back to original value: ([lindex $seq_based_route_info 0])"

            binary scan [GENERICMESSAGE::message data] x16c* im_body

            GENERICMESSAGE::message data [binary format IIIIc* $command_length $command_id $command_status [lindex $seq_based_route_info 0] $im_body]

            unset seq_rewrite_table("$proxy_side-$sequence_number")
        }
        else {
            log local0. "No matching sequence number rewrite found"     ;# T=I
        }
    }
}


when MR_INGRESS {
    set reverse_peer_name $peer_name
    set reverse_vs_or_tc_name $my_vs_or_tc_name
    set reverse_vs_or_tc_type $my_vs_or_tc_type

    MR::store reverse_peer_name reverse_vs_or_tc_name reverse_vs_or_tc_type

    if { $is_request_msg } {
        call logging::debug "serverside, requires custom routing"

        if { $message_explicit_nexthop ne "" } {
            call logging::trace "Explicitly routing based on message_explicit_nexthop = ($message_explicit_nexthop), using virtual = ($name_of_virtual_server_facing_this_smsc_cluster)"
            MR::message route virtual $name_of_virtual_server_facing_this_smsc_cluster host $message_explicit_nexthop
        }

        set message_explicit_nexthop ""
    }
    elseif { [info exists seq_based_route_info] } {
        call logging::debug "MR_INGRESS for response message"
        call logging::debug "Re-routing to [lindex $seq_based_route_info 2] ([lindex $seq_based_route_info 3]) host ([lindex $seq_based_route_info 1])"
        MR::message route [lindex $seq_based_route_info 2] [lindex $seq_based_route_info 3] host [lindex $seq_based_route_info 1]
    }
}


when MR_EGRESS {
    MR::restore reverse_peer_name reverse_vs_or_tc_name reverse_vs_or_tc_type
    call logging::debug "Restored Values: reverse_peer_name = ($reverse_peer_name), reverse_vs_or_tc_name = ($reverse_vs_or_tc_name), reverse_vs_or_tc_type = ($reverse_vs_or_tc_type)"
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
            call logging::debug "Queueing message for delivery once bind is completed"
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


when MR_FAILED {
    log local0. "MR_FAILED for serverside incoming message: [MR::message status]"
}


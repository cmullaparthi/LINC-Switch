-module(ofs_userspace_stats).
-author("Erlang Solutions Ltd. <openflow@erlang-solutions.com>").

-export([table_stats/1,
         update_aggregate_stats/4]).

-include("ofs_userspace.hrl").

%%% Stats functions ------------------------------------------------------------

table_stats(#flow_table{id = Id, entries = Entries, config = Config}) ->
    TableName = list_to_binary(io_lib:format("Flow Table 0x~2.16.0b", [Id])),
    ActiveCount = length(Entries),
    [#flow_table_counter{packet_lookups = LookupCount,
                         packet_matches = MatchedCount}] =
        ets:lookup(flow_table_counters, Id),
    #ofp_table_stats{table_id = Id,
                     name = TableName,
                     match = ?SUPPORTED_MATCH_FIELDS,
                     wildcards = ?SUPPORTED_WILDCARDS,
                     write_actions = ?SUPPORTED_WRITE_ACTIONS,
                     apply_actions = ?SUPPORTED_APPLY_ACTIONS,
                     write_setfields = ?SUPPORTED_WRITE_SETFIELDS,
                     apply_setfields = ?SUPPORTED_APPLY_SETFIELDS,
                     metadata_match = <<-1:64>>,
                     metadata_write = <<-1:64>>,
                     instructions = ?SUPPORTED_INSTRUCTIONS,
                     config = Config,
                     max_entries = ?MAX_FLOW_TABLE_ENTRIES,
                     active_count = ActiveCount,
                     lookup_count = LookupCount,
                     matched_count = MatchedCount}.

update_aggregate_stats(#ofp_aggregate_stats_reply{
                          packet_count = OldPacketCount,
                          byte_count = OldByteCount,
                          flow_count = OldFlowCount} = Reply,
                       TableId,
                       FlowEntry,
                       #ofp_aggregate_stats_request{
                         out_port = RequestOutPort,
                         out_group = RequestOutGroup,
                         cookie = RequestCookie,
                         cookie_mask = RequestCookieMask,
                         match = Match}) ->
    FlowMatchesRequestSpec =
        ofs_userspace_flow:cookie_match(FlowEntry, RequestCookie,
                                        RequestCookieMask)
        andalso
        ofs_userspace_flow:non_strict_match(FlowEntry, Match)
        andalso
        entry_writes_to_port(FlowEntry, RequestOutPort)
        andalso
        entry_writes_to_group(FlowEntry, RequestOutGroup),
    case FlowMatchesRequestSpec of
        true ->
            [#flow_entry_counter{received_packets = EntryPacketCount,
                                 received_bytes = EntryByteCount}] =
                ets:lookup(flow_entry_counters, {TableId, FlowEntry}),
            Reply#ofp_aggregate_stats_reply{
              packet_count = OldPacketCount + EntryPacketCount,
              byte_count = OldByteCount + EntryByteCount,
              flow_count = OldFlowCount + 1};
        false ->
            Reply
    end.

%%%-----------------------------------------------------------------------------
%%% Helpers
%%%-----------------------------------------------------------------------------

entry_writes_to_port(_, any) ->
    true;
entry_writes_to_port(FlowEntry, RequiredPortNo) ->
    [] =/= [x || #ofp_action_output{port = PortNo} <- get_actions(FlowEntry),
                 PortNo =:= RequiredPortNo].

entry_writes_to_group(_, any) ->
    true;
entry_writes_to_group(FlowEntry, RequiredGroupId) ->
    [] =/= [x || #ofp_action_group{group_id = GrpId} <- get_actions(FlowEntry),
                 GrpId =:= RequiredGroupId].

get_actions(#flow_entry{instructions = Instrs}) ->
    Written = [As || #ofp_instruction_write_actions{actions = As} <- Instrs],
    Applied = [As || #ofp_instruction_apply_actions{actions = As} <- Instrs],
    lists:flatten([Written, Applied]).

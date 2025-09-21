-module(xml2map_ffi).
-export([decode/1, decode_string/1]).

-include_lib("xmerl/include/xmerl.hrl").

%% Public API
decode(Bin) when is_binary(Bin) ->
    decode_string(binary_to_list(Bin));
decode(Bin) when is_list(Bin) ->
    decode_string(Bin);
decode(Io) ->
    decode_string(Io).

decode_string(String) ->
    %% xmerl_scan:string expects a charlist (string())
    {Xml, _} = xmerl_scan:string(String),
    RootList = listify(Xml),
    Map = maps:from_list([{ name_to_bin(E#xmlElement.name), element_to_map(E) } || E <- RootList]),
    {ok, Map}.

%%%% helpers %%%%
listify(E) when is_list(E) -> E;
listify(E) -> [E].

%% Convert an xmerl xmlElement -> map of its attributes, text and children
element_to_map(E = #xmlElement{}) ->
    %% attributes -> map with keys prefixed "@"
    Attrs = lists:foldl(fun(A, Acc) ->
                              maps:put(attr_key(A#xmlAttribute.name),
                                       attr_value_to_bin(A#xmlAttribute.value),
                                       Acc)
                      end, #{}, E#xmlElement.attributes),

    %% content: children and text nodes
    {ChildrenMap, TextsRev} = process_content(E#xmlElement.content, #{}, []),

    %% merge attributes and children (attrs take precedence here)
    Merged = maps:fold(fun(K, V, Acc) -> maps:put(K, V, Acc) end, Attrs, ChildrenMap),

    %% attach text if present
    case TextsRev of
        [] -> Merged;
        _ ->
            Texts = lists:reverse(TextsRev),
            TextBin = join_texts(Texts),
            maps:put(text_key(), TextBin, Merged)
    end.

%% Process content list: returns {ChildrenMap, TextsAccRev}
process_content([], AccChildren, Texts) ->
    {AccChildren, Texts};
process_content([H|T], AccChildren, Texts) ->
    case H of
        #xmlElement{} = Child ->
            ChildName = name_to_bin(Child#xmlElement.name),
            ChildMap = element_to_map(Child),
            AccChildren2 = add_child(AccChildren, ChildName, ChildMap),
            process_content(T, AccChildren2, Texts);
        #xmlText{value = Val} ->
            Text = text_value_to_bin(Val),
            NewTexts = case is_blank(Text) of
                           true -> Texts;
                           false -> [Text|Texts]
                       end,
            process_content(T, AccChildren, NewTexts);
        _Other ->
            %% ignore comments, processing-instructions, etc.
            process_content(T, AccChildren, Texts)
    end.

%% Add child under key; if multiple children with same name, produce list in order
add_child(Acc, Key, Value) ->
    case maps:get(Key, Acc, undefined) of
        undefined ->
            maps:put(Key, Value, Acc);
        Existing when is_list(Existing) ->
            %% keep order: append new child
            maps:put(Key, Existing ++ [Value], Acc);
        Existing ->
            maps:put(Key, [Existing, Value], Acc)
    end.

%%%% name / value helpers %%%%

name_to_bin(Name) when is_atom(Name) ->
    atom_to_binary(Name, utf8);
name_to_bin(Name) when is_list(Name) ->
    list_to_binary(Name);
name_to_bin(Name) when is_binary(Name) ->
    Name;
name_to_bin(Other) ->
    list_to_binary(io_lib:format("~p", [Other])).

%% attribute key prefixed with "@"
attr_key(Name) ->
    NameBin = name_to_bin(Name),
    <<$@, NameBin/binary>>.

text_key() -> <<"#text">>.

attr_value_to_bin(Value) ->
    value_to_bin(Value).

text_value_to_bin(Value) ->
    value_to_bin(Value).

value_to_bin(Value) when is_list(Value) ->
    list_to_binary(Value);
value_to_bin(Value) when is_binary(Value) ->
    Value;
value_to_bin(Value) when is_atom(Value) ->
    atom_to_binary(Value, utf8);
value_to_bin(Other) ->
    list_to_binary(io_lib:format("~p", [Other])).

%% join multiple text nodes with a single space (trim each first)
join_texts(List) ->
    Strs = [ binary_to_list(trim_bin(B)) || B <- List ],
    NonEmpty = [ S || S <- Strs, S /= [] ],
    case NonEmpty of
        [] -> <<>>;
        _ -> list_to_binary(string:join(NonEmpty, " "))
    end.

%% trim binary -> binary (using string:trim which returns a charlist)
trim_bin(Bin) when is_binary(Bin) ->
    Str = binary_to_list(Bin),
    Trimmed = string:trim(Str),
    list_to_binary(Trimmed).

%% check blank
is_blank(Bin) when is_binary(Bin) ->
    trim_bin(Bin) == <<>>.

% niter - Nitrogen Terminal (Web Unix Shell) 
% Can used standalone or as plugin to nide
% Copyright (c) 2010 Panagiotis Skarvelis
% See MIT-LICENSE for licensing information.

-module(niter).

-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

main() -> #template { file="./site/templates/bare.html" }.

title() -> "niter Nitrogen Web Terminal".

get_shelllines(Port, Data, Callback) ->     
        receive 
             'INIT' -> get_shelllines(Port, Data,Callback);                
             {'EXIT', _, _Message} -> port_command(Port, "exit\n"),port_close(Port);
             {Port, {data, Buffer}} -> Callback(Buffer),get_shelllines(Port, Data++Buffer,Callback);             
             {Port, {exit_status, _N}} -> port_command(Port, "exit\n"),port_close(Port);             
             {Port, eof} ->  port_command(Port, "exit\n"),port_close(Port);             
             {exec,This} -> port_command(Port, This),get_shelllines(Port, Data,Callback);            
             stop -> port_command(Port, "exit\n"),port_close(Port);
             _Any ->get_shelllines(Port, Data,Callback) 
end.

body() -> 
Opts = [stream, exit_status, use_stdio, stderr_to_stdout, eof, {env, [{"PS1", "niter\\$ "},{"TERM","vt100"}]} ], 
Port = open_port({spawn, "bash --noprofile --norc -i -s +o monitor "}, Opts),
writetoshell("niter\$ "),port_command(Port, "clear\n"),timer:sleep(100),%To clear some annoying messages on start of bash
									%Look here for the matter ESC [ Pn c   DA -- Device Attributes

{ok,Pid} = wf:comet(fun()-> ?MODULE:get_shelllines(Port,[],fun writetoshell/1) end,shell),
port_connect(Port, Pid),
Body = [
        #hidden{id="shell_key",text=""},
        
        #p{},
        #textarea{id=shell, class="shell",style="width: 95%;height: 420px;border: 1px solid #cccccc;"},
        #button {id=getcur,text="clickme",postback=getit},
        #p{},
        #flash{}
        ],
        wf:wire(#api {name=sendtobash, tag=f1}),
        wf:wire("
        $('.wfid_shell').keydown(function(event) {
          var charCode = (event.which) ? event.which : event.keyCode;
          if (charCode == '8') { page.sendtobash(8);}   //Backspace
          if (charCode == '38') { page.sendtobash('\\"++[27]++"[A');} //Up 
          if (charCode == '40') { page.sendtobash('\\"++[27]++"[B');} //Down 
          //TODO DEL LEFT RIGHT INSERT? ^D ^C ktlp
        });
                
        $('.wfid_shell').keypress(function(event) {
        var charCode = (event.which) ? event.which : event.keyCode;
        if (charCode == '13') { page.sendtobash('\\n'); }  else 
            page.sendtobash(String.fromCharCode(charCode))});"),            
         Body.


interpreter([],_EscFlag)->
"";
interpreter([Char|RestOfBuffer],EscFlag)->
case EscFlag of
0-> case Char of
                   8 ->  do_bs(".wfid_shell");        %Back space character
                   27->  interpreter(RestOfBuffer,1); %Esc goto mode 1                           
                    _->  wf:insert_bottom(shell, Char) %Common Char just print
     end;
1-> case Char of
    $[->interpreter(RestOfBuffer,2); %Esc goto mode 2 
     _-> wf:insert_bottom(shell, Char) %Unknown Command Just Print 
     end;

2-> case Char of
    $K-> wf:flash("Do Clear line");
     _->wf:insert_bottom(shell, Char) %Unknown Command Just Print 
    end;
_-> wf:error("Unknown Esc mode!")
end
,interpreter(RestOfBuffer,0).  

interpreter(Buffer)->
interpreter(Buffer,0).


%%
do_bs(TextArreaID)->
wf:flash("bs"),
wf:wire("
var TextArea = $('"++TextArreaID++"')[0];
var x = TextArea.selectionStart; 
TextArea.value = TextArea.value.substr(0, TextArea.selectionStart - 1) + TextArea.value.substr(TextArea.selectionEnd, TextArea.value.length);
TextArea.selectionStart = x - 1;   
TextArea.selectionEnd = x - 1;
"),
wf:flush().

%%%%
api_event(sendtobash, _, Char) ->
    wf:send(shell,{exec,Char}).

writetoshell(Buffer)->
%  wf:flash(Buffer),  
%%   wf:insert_bottom(shell,Buffer),%Here have to go to esc codes interpreter
interpreter(Buffer),
  wf:wire("obj('shell').scrollTop = obj('shell').scrollHeight;"),
wf:flush().

event(getit)->
do_bs(".wfid_shell").

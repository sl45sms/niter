% niter - Nitrogen Terminal (Web Unix Shell) 
% Can used standalone or as plugin to nide
% Copyright (c) 2010 Panagiotis Skarvelis
% See MIT-LICENSE for licensing information.

-module(niter).

-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-define(FLAG0,throw({flag,0})).
-define(FLAG1,throw({flag,1})).
-define(FLAG2,throw({flag,2})).
-define(PUTCHAR,wf:wire(wf:f("obj('shell').value = obj('shell').value +String.fromCharCode(~p);",[Char]))).%wf:insert_bottom don't work because have cache

main() -> #template { file="./site/templates/bare.html" }.

title() -> "niter Nitrogen Terminal (Web Bash Shell Wrapper)".

get_shelllines(Port, Data, Callback) ->     
        receive 
             'INIT' -> get_shelllines(Port, Data,Callback);                
             {'EXIT', _, _Message} -> port_command(Port, "exit\n"),port_close(Port);
             {Port, {data, Buffer}} -> Callback(Buffer),get_shelllines(Port, [],Callback);             
             {Port, {exit_status, _N}} -> port_command(Port, "exit\n"),port_close(Port);             
             {Port, eof} ->  port_command(Port, "exit\n"),port_close(Port);             
             {exec,This} -> port_command(Port, This),get_shelllines(Port, Data,Callback);            
             stop -> port_command(Port, "exit\n"),port_close(Port);
             _Any ->get_shelllines(Port, Data,Callback) 
end.


start()->
Opts = [stream, exit_status, use_stdio, stderr_to_stdout, eof, {env, [{"PS1", "niter\\$ "},{"TERM","vt100"}]} ], 
Port = open_port({spawn, "bash --noprofile --norc -i -s -P +m +o monitor "}, Opts),
writetoshell("niter\$ "),port_command(Port, "clear\n"),timer:sleep(100),%To clear some annoying messages on start of bash
									%Look for the matter the code: ESC [ Pn c   DA -- Device Attributes
{ok,Pid} = wf:comet(fun()-> ?MODULE:get_shelllines(Port,[],fun writetoshell/1) end,shell),
port_connect(Port, Pid).


shell()->
?MODULE:start(),
Body = [  
        #p{},    
        #textarea{id=shell, class="shell",style="width: 95%;height: 420px;border: 1px solid #cccccc;"},
        #p{},
        #flash{}
        ],
        wf:wire("obj('shell').setAttribute('readonly', 'true');"),
        wf:wire(#api {name=sendtobash, tag=f1}),
        wf:wire("
        $('.wfid_shell').keydown(function(event) {
          var charCode = (event.which) ? event.which : event.keyCode;
          if (charCode == '8') { page.sendtobash(8);}   //Backspace
          if (charCode == '38') { page.sendtobash('\\"++[27]++"[A');} //Up 
          if (charCode == '40') { page.sendtobash('\\"++[27]++"[B');} //Down 
          //TODO DEL LEFT RIGHT INSERT? ^D ^C etc
        });
                
        $('.wfid_shell').keypress(function(event) {
        var charCode = (event.which) ? event.which : event.keyCode;
        if (charCode == '13') { page.sendtobash('\\n'); }     
         else  page.sendtobash(String.fromCharCode(charCode))});"),           
         Body.


body() -> 
shell().

%%%Partial VT100 Escape sequences interpreter
interpreter([],_)->
[]; 

interpreter([Char| RestOfBuffer], EscFlag)->
try
case EscFlag of
 0 -> case Char of
           8 ->  do_bs(),?FLAG0; %Back space character
          27 ->  ?FLAG1; %Esc goto mode 1                           
            _-> ?PUTCHAR,?FLAG0                   
      end;
 1 -> case Char of %Esc depth 1
           $[-> ?FLAG2; %Esc goto mode 2 
            _-> ?PUTCHAR,?FLAG0  %Unknown Command Just Print
      end;
 2 -> case Char of %Esc depth 2
           $K-> do_EL0(),?FLAG0; 
           $H ->do_cursorhome,?FLAG0;
           $J ->do_ED0(),?FLAG0;
            _-> ?PUTCHAR,?FLAG0  %Unknown Command Just Print 
      end;
_-> wf:flash("Unknown Esc mode!"),?FLAG0
end
catch
    throw:{flag,Flag} -> interpreter(RestOfBuffer,Flag) 
end.
 
interpreter(Buffer)->
interpreter(Buffer,0).
 
%%VT100 Commands
%%Name of command's is from http://ascii-table.com/ansi-escape-sequences-vt-100.php

do_bs()-> %Backspace %TODO make it simpler cause i don't have plans to handle cursor at the moment
wf:wire("obj('shell').removeAttribute('readOnly');"),
wf:wire("
var x = obj('shell').selectionStart; 
obj('shell').value = obj('shell').value.substr(0, obj('shell').selectionStart - 1) + obj('shell').value.substr(obj('shell').selectionEnd, obj('shell').value.length);
obj('shell').selectionStart = x - 1;   
obj('shell').selectionEnd = x - 1;
"),
wf:wire("obj('shell').setAttribute('readonly', 'true');").

do_EL0()->%Esc[K Clear line from cursor right
"". %No need to do anything

do_cursorhome()->%Esc[H Move cursor to upper left corner
"". %No need to do anything

do_ED0()->%Esc[J Clear screen from cursor down
wf:wire("obj('shell').value ='';").%Just clean up the entire screen, i have no plans to handle cursor 
 
%%%%
%Put the same events on nide to make it work as plugin
api_event(sendtobash, _, Char) ->
    wf:send(shell,{exec,Char}).

writetoshell(Buffer)->
%For debug - wf:flash(Buffer),
_Val = niter:interpreter(Buffer),
 wf:wire("obj('shell').scrollTop = obj('shell').scrollHeight;"),
wf:flush().
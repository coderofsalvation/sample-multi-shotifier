#!/bin/bash
TMPFILE="/tmp/.bashweb.$(whoami)"
PORT=8000

start(){
   [[ -n "$1" ]] && PORT="$1"; TMPFILE="$TMPFILE.$PORT"; [[ ! -p $TMPFILE ]] && mkfifo "$TMPFILE"
   which xdg-open &>/dev/null && xdg-open "http://localhost:$PORT" || echo "[x] surf to http://localhost:$PORT"
   while [[ -p "$TMPFILE" ]]; do
     [[ -f "$TMPFILE.log" ]] && tail -n5 $TMPFILE.log
     { read line<$TMPFILE;
       logmsg(){ cat - | while read l; do echo "[$(date)] $1> $l" >> $TMPFILE.log; [[ ! "$1" == "in" ]] && echo "$l"; done; }
       message="$( echo "$line" | sed 's/[\n\r]//g')"
       method="$(echo "$message" | sed 's/ \/.*//g' )"
       url="$(echo "$message" | sed 's/GET //g;s/POST //g;s/DELETE //g;s/PUT //g;s/ HTTP.*//g')"
       echo "$method $url" | logmsg in
       echo -e "HTTP/1.1 200 OK\r\n"  | logmsg out
       $0 onUrl "$method" "$url" "$TMPFILE"
     } | nc -v -l $PORT > $TMPFILE | tee -a $TMPFILE.log
   done
}

onUrl(){
  method="$1";  url="$(echo "$2" | sed 's/?.*//g')"; args="$(echo "$2" | sed 's/.*?//g;s/&/\n/g')"
  tmpfile="$3"; file="html$url"
  
  case $url in

    /)        serveFile "html/index.html" "$method" "$url" "$args" "$tmpfile"
              ;;

    /rest)    echo '{"code":0, "message": "'$(date)'" }'
              ;;

    /log)     echo "<html><body><pre>$(tail -n15 "$3.log")</pre></body></html>"
              ;;

    *)        [[ -f "$file" ]] && serveFile "$file" "$method" "$url" "$args" "$tmpfile" || 
                echo "bashwapp> $file not found"
              ;;
  esac
}

serveFile(){
  file="$1"; [[ ! -f "$file" ]] && echo "file $file not found" && return 1
  if [[ -f "$file.handler" ]]; then                      # and if a file(.handler) file is found
    echo "cat $file | $file.handler $2 $3 $4" >> $4.log
    cat "$file" | $file.handler "$2" "$3" "$4" 2>&1      # output the file and filter using handler
  else cat "$file"; fi # or just output the file (images/css/eg)
}


cleanup(){
  [[ -f "$TMPFILE" ]] && rm "$TMPFILE"
  echo "server stopped"
  exit
}

trap cleanup SIGINT
if [[ -n "$1" ]]; then "$@"; else start; fi

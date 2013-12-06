#!/bin/bash
#
# deadsimple bash webserver + html (bash) templates
#
# Usage: ./app
#
# Copyright 2013 Coder of Salvation. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY Coder of Salvation AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Coder of Salvation OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied, of Coder of Salvation.
 

TMPFILE="/tmp/.bashwapp.$(whoami)"
PORT=8000
pid=$$
CLIENT=$TMPFILE.fifo 
MYPATH="$(dirname "$(readlink -f "$0")" )"

start(){
  [[ -n "$1" ]] && PORT="$1"; TMPFILE="$TMPFILE.$PORT"; 
  which xdg-open &>/dev/null && xdg-open "http://localhost:$PORT" || echo "[x] surf to http://localhost:$PORT"
  console "" "server started @ localhost:$PORT"
  [[ ! -p $CLIENT ]] && mkfifo $CLIENT 
  while [[ -p $CLIENT ]]; do cat $CLIENT | nc -v -l $PORT 2>&1 | onRequest; done
  rm $TMPFILE.*
}

console(){
  echo "[$(date)] bashwapp $1 $2" | tee -a $TMPFILE.log; return 0
}

onRequest(){
  cat - | while read line; do 
    [[ -n $DEBUG ]] && console "<=" "$line" || console "<=" "$line" &>/dev/null
    [[ "$line" =~ "Connection from " ]] && CLIENT_IP="$(echo "$line" | sed s'/Connection from \[//g;s/\].*//g' )"
    [[ "$line" =~ "GET "             ]] || [[ "$line" =~ "GET"  ]] && parseUrl "$line" "GET"
    [[ "$line" =~ "POST "            ]] || [[ "$line" =~ "POST" ]] && parseUrl "$line" "POST"
    [[ "$line" =~ "Host: "           ]] && CLIENT_HOST="$(echo "$line" | sed 's/Host: //g')"
    [[ "$line" =~ "User-Agent: "     ]] && CLIENT_USERAGENT="$(echo "$line" | sed 's/User-Agent: //g')"
    [[ "$line" =~ "Accept: "         ]] && CLIENT_ACCEPT="$(echo "$line" | sed 's/Accept: //g')"
    if (( ${#line} == 1 )); then (onUrl "$CLIENT" "$CLIENT_URL" &); fi
  done
}

parseUrl(){
  line="$1"; method="$2"
  CLIENT_URL="$(echo "$line" | sed "s/$method //g;s/ .*//g;s/?.*//g")"
  CLIENT_ARGS="$(echo "$line" | sed "s/.*?//g;s/ .*//g")"
  # turn getvars into variables
  IFSOLD=$IFS; IFS='&'; for arg in $CLIENT_ARGS; do key="$(echo "${arg/=*/}" | urldecode )"; value="$(echo "${arg/*=/}" | urldecode)"; eval "$key=\"$value\""; done 
  IFS=$IFSOLD;
}

onUrl(){
  console "<=" "$CLIENT_METHOD $CLIENT_URL $CLIENT_ARGS"
  case "$CLIENT_URL" in 

    /)        serveFile "html/index.html" $CLIENT
              ;;

    /rest)    echo '{"code":0, "message": "'$(date)'" }' > $CLIENT
              ;;

    /log)     echo "<html><body><pre>$(tail -n45 "$TMPFILE.log")</pre></body></html>" > $CLIENT
              ;;

    /quit)    echo "Application terminated" > $CLIENT; rm $CLIENT;
              ;;

    *)        [[ -f "html$CLIENT_URL" ]] && serveFile "html$CLIENT_URL" $CLIENT || { httpheader 404 > $CLIENT; console "!>" "html$CLIENT_URL not found"; }
              ;;
  esac
}

httpheader(){
  code=$1; file="$2"
  case $code in 
    200) echo "HTTP/1.0 200 OK" 
         echo -e "Content-Length: $(stat -c%s "$file")\r\n"
         ;;
    404) echo "HTTP/1.0 404 Not Found\r\n"
         ;;
  esac
}

serveFile(){
  file="$1"; CLIENT="$2"
  [[ ! -f "$file" ]] && console "=>" "file $file not found" && httpheader 404 > $CLIENT && return 1
  [[ -f "$file.handler" ]] && source $file.handler && console "=>" "source $file.handler" 
  cd "$MYPATH"; # return for sure
  console "=>" "serving $file"
  cat "$file" | fetch > $TMPFILE.output 
  { httpheader 200 "$TMPFILE.output"; cat "$TMPFILE.output"; } > $CLIENT 
}

urldecode(){
  data="$(cat - | sed 's/+/ /g')"
  printf '%b' "${data//%/\x}"
}

cleanup(){
  echo "server stopped"
  exit 0
}

# smarty like template engine which executes inline bash in html / replaces variables with values 
fetch(){
  IFSOLD=$IFS; IFS=''; cat - | while read line; do 
    for k in "${!args[@]}"; do [[ "$k" == "0" ]] && continue;
      value="$( echo "${args["$k"]}" | sed -e 's/[\/&]/\\&/g' | sed "s/'/\"/g" )"; eval "$k="$value";"
    done; 
    line="$(eval "echo \"$( echo "$line" | sed 's/"/\\"/g')\"")"; echo "$line" # process bash in snippet
  done
  IFS=$IFSOLD;
}

trap cleanup SIGINT
if [[ -n "$1" ]]; then "$@"; else start; fi

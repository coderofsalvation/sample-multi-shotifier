getArg(){
  key="$1"; getargs="$2"
  echo "$getargs" | while read line; do
    key="$(echo "$line" | sed 's/=.*//g')"
    value="$(echo "$line" | sed 's/.*=//g' | urldecode)"
    [[ "$key" == "$1" ]] && echo "$value"
  done
}

replace(){
  source="$1"; dest="$2";
  cat - | while read line; do 
    if echo "$line" | grep "$source" &>/dev/null; then echo "$dest"
    else echo "$line"; fi
  done
}

urldecode(){
  data="$(cat - | sed 's/+/ /g')"
  printf '%b' "${data//%/\x}"
}


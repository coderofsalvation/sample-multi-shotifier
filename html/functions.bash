declare -A args    # array holding shared bash/html/formvars

initArg(){ # this functions adds a variable to args, and initializes it with a formGET / or default value
  webargs="$1"; var="$2"; defvalue="$3";
  args["$var"]="$(getArg "$var" "$webargs")"
  [[ ${args["$var"]} == "" ]] && args["$var"]="$defvalue"
}

getArg(){ # this function parses a http query string and gets the value of a key
  key="$1"; getargs="$2"
  echo "$getargs" | while read line; do
    key="$(echo "$line" | sed 's/=.*//g')"
    value="$(echo "$line" | sed 's/.*=//g' | urldecode)"
    [[ "$key" == "$1" ]] && echo "$value"
  done
}

urldecode(){
  data="$(cat - | sed 's/+/ /g')"
  printf '%b' "${data//%/\x}"
}

#
# quick and dirty template engine functions
#

replace(){ # quick n dirty multiline search/replace
  source="$1"; dest="$2";
  cat - | while read line; do 
    if echo "$line" | grep "$source" &>/dev/null; then echo "$dest"
    else echo "$line"; fi
  done
}

templatify(){ # quick n dirty inline search/replace using sed (note dont use '|' in replace strings)
  output="$(cat -)"
  for k in "${!args[@]}"; do
    [[ "$k" == "0" ]] && continue;
    value="$( echo "${args["$k"]}" | sed -e 's/[\/&]/\\&/g' | sed "s/'/\"/g" )"
    output="$( echo "$output" | sed "s|%$k%|$value|g" )"
  done; 
  echo "$output"
}

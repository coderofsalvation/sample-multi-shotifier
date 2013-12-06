#!/bin/bash 

_collect(){
  files=0; dir="$1"; nfiles="$2"; nstartfile="$3"; normalize="$4"; maxlength="$5"; trim="$6"; recursive="$7"; slice="$8"
  [[ ! -d /tmp/.collect ]] && mkdir /tmp/.collect || rm /tmp/.collect/* &>/dev/null
  [[ ! -d /tmp/.slices  ]] && mkdir /tmp/.slices || rm /tmp/.slices/* &>/dev/null
  (( $normalize == 1 )) && normalize="--norm"
  echo "./collect $dir $nfiles $nstartfile $normalize $maxlength $trim $recursive $slice"
  echo "$dir" | grep "\*\." &>/dev/null && dir="$(dirname "$dir")";
  cd "$dir"; echo "cd'ing to $(pwd)"; offset=0
  (( $recursive == 1 )) && listcmd="find -L . -name '*wav' -not -path '*/\.*'" || listcmd="ls *.wav"
  eval "$listcmd" | tail -n+$nstartfile > $TMPFILE.filelist
  while read -r wavfile; do
    wavfile="$(echo "$wavfile" | sed 's/\.\///g')"
    echo "checking $wavfile ($samples samples < $maxlength, files/nfiles: $files/$nfiles)"
    samples="$(soxi "$wavfile" | grep Duration | cut -d' ' -f11 )"
    if [[ ${#samples} > 0 ]] && 
       (( samples < maxlength )) && (( $files < $nfiles )); then
      echo "processing ($files) $wavfile"; name="$(basename "$wavfile" | sed 's/WAV/wav/g')"
      # if slices is enabled, disable the trim (and set to maxtrim to prevent long waiting times)
      (( slice > 0 )) && pretrim="$maxtrim" || pretrim="$trim"
      sox "$wavfile" $normalize -c 2 -e signed -b 16 -r 44100 "/tmp/.collect/$name.trimmed.wav" trim ${pretrim}
      if (( slice == 1 )); then 
        slice "/tmp/.collect/$name.trimmed.wav" /tmp/.slices "$trim" "$nfiles"
        files=$(ls -1 /tmp/.slices | wc -l )
      else ((files=files+1)); fi
    fi
    if (( files >= nfiles )); then break; fi 
  done < $TMPFILE.filelist
  echo "collected $files items (wanted=$nfiles)"
}

# pad sample to length (fills with silence or cuts sample)
# <input.wav> <00:00:00.00 =00:00:00.00s> <normalize>
padsample(){
  inputfile="$1"; trim="$2"; normalize="$3"
  [[ ${#normalize} != 0 ]] && normalize="norm"
  silencefile="/tmp/.collect/multishotsilence.$(echo "$trim" | sed 's/ /-/g').wav"
  [[ ! -f "$silencefile" ]] && sox -n -e signed -b 16 -r 44100 -c 2 "$silencefile" trim ${trim} 2>&1 # create silence file to enable exact padding
  sox -m "$silencefile" "$inputfile" "$inputfile.padded.wav" $normalize # pad wav
  echo "padding sample $inputfile to $trim"
}

# bundles all .wav files in a dir into one file, makes it mono, pitches up, does custom stuff, pads samples with silence, normalizes
# <indir> <outfile.wav> <mono> <pitchup:1.0> <soxextra> <00:00:00.0 =00:00:00.40> <normalize>
_bundle(){
  indir="$1"; outfile="$2"; nfiles="$3"; mono="$4"; pitchup="$5"; soxextra="${6}"; trim="$7"; normalize="$8" 
  echo "_bundle $indir $outfile $nfiles $mono $pitchup $soxextra $trim $normalize"
  [[ ${#mono} != 0 ]] && mono="-c 1"
  cd "$indir"
  rm *.padded.wav &>/dev/null
  ls *.wav | while read file; do padsample "$file" "$trim" "$normalize"; done
  if ls *.padded.wav &>/dev/null; then 
	  files="$(ls *.padded.wav | head -n$nfiles )"
    sox ${files} $mono $outfile speed "$pitchup" 
    extra="$( printf "$soxextra" "$outfile" "$outfile.wav")"; echo "$extra";
    ${extra}; mv "$outfile.wav" "$outfile" &>/dev/null
    echo "written $(echo "$files" | wc -l) samples to $outfile ($(stat -c%s "$outfile") bytes)"
  else echo "no wavfiles found to glue to output file"; fi
  rm *.padded.wav
}

# slices a sample into seperate samples based on transients :
# <input.wav> <outputdir> <00:00:00.0 =00:00:00.50> <maxslices>
slice(){
  input="$1"; outdir="$2"; trim="$3"; maxslices="$4"
  which bc &>/dev/null || { echo "please install 'bc' from your package manager"; exit 1; }
  which vamp-simple-host &>/dev/null || { echo "please install 'vamp-examples' from your package manager"; exit 1; }
  hits="$(vamp-simple-host vamp-example-plugins:percussiononsets "$input" 2>/dev/null | grep -E " [0-9].*" | sed 's/ //g;s/://g')";
  echo "$hits" > $TMPFILE.hits
  declare -a hitArray; last=""; i=0
  while read -r line; do echo "$line"; hitArray[$i]="$line"; ((i++)); done < $TMPFILE.hits
  for((i=0;i<${#hitArray[@]}-1;i++)); do
    hit=${hitArray[$i]}
    hitnext=${hitArray[$i+1]}
    length="$( echo "($hitnext-$hit)" | bc )"; [[ ${length:0:1} == "." ]] && length="0$length"
    # shift sample into the past a bit to avoid clicksounds on bassdrums (prevent too extreme cut)
    (( $i > 0 )) && hit="$(echo "$hit" | bc )";[[ ${hit:0:1} == "." ]] && hit="0$hit"
    outfile="$outdir/$(basename "$input.slice-$i.wav" )"
    echo "writing $outfile slice #$i"
    sox "$input" "$outfile" trim $hit $length trim ${trim} # fade t 0 $length 0.02
    (( i >= maxslices )) && return 0
  done
  IFS=$IFSOLD # this one caused me headaches 
}

_writemultishot(){
  # convert checkboxes into normal values
  [[ ${#slice}       > 0 ]] && slice=1       || slice=0
  [[ ${#normalize}   > 0 ]] && normalize=1   || normalize=0
  [[ ${#recursive}   > 0 ]] && recursive=1   || recursive=0
  [[ ${#mono}        > 0 ]] && mono=1        || mono=0
  [[ ${#esxoptimize} > 0 ]] && esxoptimize=1 || esxoptimize=0
  :>$TMPFILE.multishotlog
  {
    _collect "$selecteddir"  \
             "$nfiles"       \
             "$nstartfile"   \
             "$normalize"    \
             "$sampleframes" \
             "$sampletrim"   \
             "$recursive"    \
             "$slice" 
      if (( $slice == 1 )); then indir="/tmp/.slices"; else indir="/tmp/.collect"; fi
#verrrry easy probably
#indir="/tmp/.collect"
      _bundle  "$indir"       \
               "$outfile"     \
               "$nfiles"      \
               "$mono"        \
               "$pitchup"     \
               "$soxextra"    \
               "$sampletrim"  \
               "$normalize"   
  } 2>&1 | while read line; do echo "$line"; echo "$line" >> $TMPFILE.multishotlog; done
}


#!/bin/bash 

_collect(){
  files=0; dir="$1"; nfiles="$2"; nstartfile="$3"; normalize="$4"; maxlength="$5"; trim="$6"; recursive="$7"; slice="$8"
  [[ ! -d /tmp/.collect ]] && mkdir /tmp/.collect || rm /tmp/.collect/* &>/dev/null
  [[ ! -d /tmp/.slices  ]] && mkdir /tmp/.slices || rm /tmp/.slices/* &>/dev/null
  (( $normalize == 1 )) && normalize="--norm"
  maxtrim="00:00:00.0 00:10:00.0"
  echo "./collect $dir $nfiles $nstartfile $normalize $maxlength $trim $recursive $slice"
  echo "$dir" | grep "\*\." &>/dev/null && dir="$(dirname "$dir")";
  cd "$dir"; echo "cd'ing to $(pwd)"; offset=0
  (( $recursive == 1 )) && listcmd="find -L . -name '*wav' -not -path '*/\.*'" || listcmd="ls *.wav"
  eval "$listcmd" | tail -n+$nstartfile > $TMPFILE.filelist
  while read -r wavfile; do
    wavfile="$(echo "$wavfile" | sed 's/\.\///g')"
    echo "$wavfile"
    samples="$(soxi "$wavfile" | grep Duration | cut -d' ' -f11 )"
    if [[ ${#samples} > 0 ]] && 
       (( samples < maxlength )) && (( $files < $nfiles )); then
      echo "-> processing $wavfile ($samples samples < $maxlength, files/nfiles: $files/$nfiles)"; name="$(basename "$wavfile" | sed 's/WAV/wav/g')"
      # if slices is enabled, disable the trim (and set to maxtrim to prevent long waiting times)
      if (( slice > 0 )); then pretrim="$maxtrim"; else pretrim="$trim"; fi
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
  inputfile="$1"; trim="$2"; normalize="$3"; 
  [[ ${#normalize} != 0 ]] && normalize="norm"
  echo "padding sample $inputfile to $trim"
  if [[ ${#padreverse} > 0 ]]; then 
    sox "$inputfile" "$inputfile.paddedreversed.wav" repeat 4 reverse 
    sox "$inputfile" "$inputfile.paddedreversed.wav" "$inputfile.padded.wav" $normalize trim ${trim} # append & pad wav
    echo "Reversed!"
  else
    silencefile="/tmp/.collect/multishotsilence.$(echo "$trim" | sed 's/ /-/g').wav"
    [[ ! -f "$silencefile" ]] && sox -n -e signed -b 16 -r 44100 -c 2 "$silencefile" trim ${trim} 2>&1 # create silence file to enable exact padding
    sox -m "$silencefile" "$inputfile" "$inputfile.padded.wav" $normalize # pad wav
  fi
}

# bundles all .wav files in a dir into one file, makes it mono, pitches up, does custom stuff, pads samples with silence, normalizes
# <indir> <outfile.wav> <nfiles> <mono> <pitchup:1.0> <soxextra> <00:00:00.0 =00:00:00.40> <normalize> <esxpoptimize>
_bundle(){
  indir="$1"; outfile="$2"; nfiles="$3"; mono="$4"; pitchup="$5"; soxextra="${6}"; trim="$7"; normalize="$8"; 
  esxoptimize="$9"; 
  echo "_bundle $indir $outfile $nfiles $mono $pitchup $soxextra $trim $normalize $esxoptimize"
  (( mono == 1 )) && monoarg="-c 1"
  cd "$indir"
  rm *.padded.wav &>/dev/null
  ls *.wav | while read file; do padsample "$file" "$trim" "$normalize"; done
  if ls *.padded.wav &>/dev/null; then 
	  #files="$(ls *.padded.wav | head -n$nfiles )"
    files=( *.padded.wav );
    echo sox ${files[@]:1:$nfiles} ${monoarg} $outfile speed "$pitchup" 
    sox "${files[@]:0:$nfiles}" ${monoarg} $outfile speed "$pitchup" 
    extra="$( printf "$soxextra" "$outfile" "$outfile.wav")"; echo "$extra";
    ${extra}; mv "$outfile.wav" "$outfile" &>/dev/null
    echo "written $(echo "$files" | wc -l) samples to $outfile ($(stat -c%s "$outfile") bytes)"
  else echo "no wavfiles found to glue to output file"; fi
  if (( $esxoptimize > 0 )); then optimizeESX "$outfile" "$pitchup" "$mono"; fi
  rm *.padded.wav
}

optimizeESX(){
  file="$1"; pitch="$2"; mono="$3"; padding=1250;
  (( $mono == 0 )) && ((padding=padding*2))
  padding=$( echo "$padding*$pitch" | bc | xargs printf "%1.0f" );
  echo "esxoptimize: trimming $padding samples to ensure proper startposition-snap"
  sox "$file" "$file.wav" trim "$padding"s && mv "$file.wav" "$file"
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
  while read -r line; do hitArray[$i]="$line"; ((i++)); done < $TMPFILE.hits
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
}

_writemultishot(){
  _outfile="$outfile"
  # convert checkboxes into normal values
  [[ ${#slice}       > 0 ]] && _slice=1       || _slice=0
  [[ ${#normalize}   > 0 ]] && _normalize=1   || _normalize=0
  [[ ${#recursive}   > 0 ]] && _recursive=1   || _recursive=0
  [[ ${#mono}        > 0 ]] && _mono=1        || _mono=0
  [[ ${#esxoptimize} > 0 ]] && _esxoptimize=1 || _esxoptimize=0
  [[ ${#padreverse} > 0  ]] && _padreverse=1 || _padreverse=0
  :>$TMPFILE.multishotlog
  {
    _collect "$selecteddir"   \
             "$nfiles"        \
             "$nstartfile"    \
             "$_normalize"    \
             "$sampleframes"  \
             "$sampletrim"    \
             "$_recursive"    \
             "$_slice" 
      if (( $slice == 1 )); then indir="/tmp/.slices"; else indir="/tmp/.collect"; fi
      _bundle  "$indir"        \
               "$_outfile"     \
               "$nfiles"       \
               "$_mono"        \
               "$pitchup"      \
               "$soxextra"     \
               "$sampletrim"   \
               "$_normalize"   \
               "$_esxoptimize" 
  } 2>&1 | while read line; do echo "$line"; echo "$line" >> $TMPFILE.multishotlog; done
}


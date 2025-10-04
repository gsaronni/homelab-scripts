#! bin/bash

#20220726: Creation
#- Improvements?
#- make a list of all nodes and loop the commands
#20220728_v0.1.1
#- Made for loops
#20220728_v0.1.2
#- try to collapse list and disable commands
#v1.3
#- Added draft of the others
#- you cannot have nested lists in bash. Python needed
#20220801_v1.4
#- Finished all 3

t71-switcher () {
  echo T1
  jiggle=""
  if [[ "$answer" == *"e"* ]]; then
    jiggle="enabled"
  elif [[ "$answer" == *"d"* ]]; then
    jiggle="disabled"
  fi
  f5BePro=("oss231" "oss245" "oss237bepro") 
  for i in "${f5BePro[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-PRO; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-PRO; modify /ltm node $i session user-$jiggle"
    fi
  done
  f5BeOmt=("10.129.173.142%3" "10.129.173.162%3" "oss261v" "10.129.173.149%3" "oss231" "oss245" "oss234v" "10.129.173.51%3" "10.129.173.148%3") 
  for i in "${f5BeOmt[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-OMT; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-OMT; modify /ltm node $i session user-$jiggle"
    fi
  done
  if [[ "$answer" == *"l"* ]]; then
    tmsh -c "cd /F5_FE-DMZ/ ; list /ltm node 10.129.164.78%4" | grep -E 'node|session'
  else
    tmsh -c "cd /F5_FE-DMZ/; modify /ltm node 10.129.164.78%4 session user-$jiggle"
  fi
  f5FeDmzExt=("oss231" "oss245" "10.129.164.99%5")
  for i in "${f5FeDmzExt[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_FE-DMZ-ext; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_FE-DMZ-ext; modify /ltm node $i session user-$jiggle"
    fi
  done
}

t72-switcher () {
  echo T2
  jiggle=""
  if [[ "$answer" == *"e"* ]]; then
    jiggle="enabled"
  elif [[ "$answer" == *"d"* ]]; then
    jiggle="disabled"
  fi
  if [[ "$answer" == *"l"* ]]; then
    tmsh -c "cd /F5_FE-DMZ/ ; list /ltm node 10.129.164.79%4" | grep -E 'node|session'
  else
    tmsh -c "cd /F5_FE-DMZ/; modify /ltm node 10.129.164.79%4 session user-$jiggle"
  fi
  f5BePro2=("10.129.175.76%2" "oss134v" "oss232")
  for i in "${f5BePro2[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-PRO; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-PRO; modify /ltm node $i session user-$jiggle"
    fi
  done
  f5BeOmt2=("10.129.173.52%3" "oss246" "10.129.173.130%3" "oss243" "oss235v" "10.129.173.133%3" "10.129.173.144%3" "oss262v")
  for i in "${f5BeOmt2[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-OMT; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-OMT; modify /ltm node $i session user-$jiggle"
    fi
  done
  f5FeDmzExt2=("oss232" "oss246" "10.129.164.110%5" "oss232")
  for i in "${f5FeDmzExt2[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_FE-DMZ-ext; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_FE-DMZ-ext; modify /ltm node $i session user-$jiggle"
    fi
  done
}

t73-switcher () {
  echo T3
  jiggle=""
  if [[ "$answer" == *"e"* ]]; then
    jiggle="enabled"
  elif [[ "$answer" == *"d"* ]]; then
    jiggle="disabled"
  fi
  if [[ "$answer" == *"l"* ]]; then
    tmsh -c "cd /F5_FE-DMZ/ ; list /ltm node 10.129.164.80%4" | grep -E 'node|session'
  else
    tmsh -c "cd /F5_FE-DMZ/; modify /ltm node 10.129.164.80%4 session user-$jiggle"
  fi
  f5BePro3=("oss233" "oss205v" "10.129.175.77%2")
  for i in "${f5BePro3[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-PRO; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-PRO; modify /ltm node $i session user-$jiggle"
    fi
  done
  f5BeOmt3=("oss233" "oss236v" "10.129.173.204%3" "10.129.173.134%3" "10.129.173.151%3" "10.129.173.153%3" "10.129.173.163%3" "oss263v")
  for i in "${f5BeOmt3[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-OMT; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-OMT; modify /ltm node $i session user-$jiggle"
    fi
  done
  f5FeDmzExt3=("oss233" "oss247")
  for i in "${f5FeDmzExt3[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_FE-DMZ-ext; list /ltm node $i" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_FE-DMZ-ext; modify /ltm node $i session user-$jiggle"
    fi
  done
}

main() {
  while true; do
    read -p "Which patching are you up to? 123>> " pick
      case $pick in
        1|2|3 )
          while true; do
            read -p "Would you like to list, disable or enable? ldeq>> " answer
            case $answer in
              [edl]* ) t7$pick-switcher;;
              [Qq]* ) break;;
              * ) echo "Please insert list, disable or enable";;
            esac
          done
        ;;
        [Qq]* ) 
          echo "Bye!" 
          break;;
        * ) echo "Please insert 1, 2 or 3";;
      esac
  done
}

echo $(date +%H:%M:%S) Hello!
main

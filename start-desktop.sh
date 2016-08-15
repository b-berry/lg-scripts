# TMUX Start Desktop Session

TMUX_NAME="desktop"

# Test for exisitng active session
if [ ! -z $TMUX ]; then
  echo "TMUX session detected, aboring!"
  echo "... unset \$TMUX and run again."
  exit 1
fi

# If attach succedes, exit script
tmux att -t ${TMUX_NAME} && exit 0

# If attach failed, create session
echo "Building tmux: ${TMUX_NAME}"
tmux new-sess -s ${TMUX_NAME} -d

for i in {1..5}; do 
    case $i in
    3) cd $HOME/src
       echo "...Creating window: SRC"
       tmux new-window -t "${TMUX_NAME}:${i}" -n "SRC"
    ;; 
    4) cd $HOME/src/lg_chef
       echo "...Creating window: CHEF"
       tmux new-window -t "${TMUX_NAME}:${i}" -n "CHEF"
    ;;
    *) cd $HOME 
       echo "...Creating window: ${i}"
       tmux new-window -t "${TMUX_NAME}:${i}"
    ;;
    esac
done

# Join tmux
echo "Attaching to tmux: ${TMUX_NAME}"
tmux select-window -t "${TMUX_NAME}:1"
tmux att -t ${TMUX_NAME} || exit 1

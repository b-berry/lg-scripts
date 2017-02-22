# TMUX Start Desktop Session

TMUX_NAME="desktop"
XTEST=$(DISPLAY=:0 xrandr | grep -c " connected")

echo "Running xrandr test: $XTEST"
case $XTEST in
    1)
    echo "...Found single display, setting up default workspace."
    xrandr --output eDP1 --mode 1920x1080 --pos 0x0 --rotate normal --output HDMI1 --off --output DP1 --off --output VIRTUAL1 --off
    ;;

    2)

    echo "...Found multiple displays connected, setting up default dual workspace."  
    xrandr --output eDP1 --mode 1920x1080 --pos 0x0 --rotate normal --output HDMI1 --mode 1680x1050 --pos 1920x0 --rotate normal --output DP1 --off --output VIRTUAL1 --off
    ;;
    *)
    echo "FAIL: xrandr test.  Abording!" && exit 1
    ;;

esac

# Test for exisitng active session
tmux has-session -t $TMUX_NAME 2>/dev/null
if [ "$?" -eq 1 ]; then
    echo "Building tmux: ${TMUX_NAME}"
    for i in {1..5}; do 
        case $i in
        1) tmux -q new-sess -d -s $TMUX_NAME &&\
           tmux new-window -t "${TMUX_NAME}:${i}"
        ;;
        3) cd $HOME/src
           echo "...Creating window: SRC"
           tmux new-window -t "${TMUX_NAME}:${i}" -n "SRC"
        ;; 
        4) cd $HOME/src/lg_chef
           echo "...Creating window: CHEF"
           tmux new-window -t "${TMUX_NAME}:${i}" -n "CHEF"
        ;;
        5) cd $HOME/src/lg_chef
           echo "...Creating window: ${i}"
           tmux new-window -t "${TMUX_NAME}:${i}" 
        ;;
        *) cd $HOME 
           echo "...Creating window: ${i}"
           tmux new-window -t "${TMUX_NAME}:${i}"
        ;;
        esac
    done
else
    echo "Existing tmux session found: ${TMUX_NAME}"
fi

# Join tmux
echo "Attaching to tmux: ${TMUX_NAME}"
xfce4-terminal --geometry 225x54+42+52 --command="tmux att -t ${TMUX_NAME}" #-c tmux select-window -t 1"

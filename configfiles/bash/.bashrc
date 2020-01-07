if [[ $- != *i* ]] ; then
	# Shell is non-interactive.  Be done now!
	return
fi


alias vim=gvim
alias originpro="~/wine.sh /home/lukas/.wine/drive_c/Program\ Files/OriginLab/Origin2017/Origin94.exe"
alias sleep="echo -n mem > /sys/power/state"
alias telegram="~/bin/Telegram/Telegram"
alias zf="zathura --fork"
alias email="thunderbird &>/dev/null &" 
alias start="/home/lukas/start.sh"
alias lan="dhcpcd en3s0"
alias wlan="/home/lukas/wlan.sh"



# Start ssh-agent if not already running
if ! pgrep -c -u "${USER}" ssh-agent &>/dev/null ; then
	ssh-agent -s | grep -Fv 'echo' > ~/.ssh/ssh-agent-env && \
		source ~/.ssh/ssh-agent-env
elif [[ -e ~/.ssh/ssh-agent-env ]] ; then
	source ~/.ssh/ssh-agent-env
else
	echo "[1;31m * ERROR:[m Could not start 'ssh-agent'" >&2
fi

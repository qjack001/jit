#!/bin/bash

# TODO:
# add checks for failed commits, pushes, etc
# make work on other platforms than macOS

fileName=()
changeType=()
selected=()
selectionIndex=0
length=0
branchName=""
sync=""
breakOut=true

function get_branch
{
	echo $(git rev-parse --abbrev-ref HEAD)
}

function go_fetch
{
	VALUES=$(git rev-list --left-right --count master...origin/master) ## fix: make work for current branch rather than just main branch
	val=($VALUES)
	
	if [[ "${val[0]}" == "0" ]]; then
		if [[ "${val[1]}" == "0" ]]; then
			echo "Up-to-date"
		else
			echo "${val[1]} ⇩ "
		fi
	else
		if [[ "${val[1]}" == "0" ]]; then
			echo "${val[0]} ⇧ "
		else
			echo "${val[1]} ⇩   ${val[0]} ⇧ "
		fi
	fi
}

function draw_top_box
{
	tput setaf 7
	echo "┌─${branchName//?/─}─┬─${sync//?/─}─┐"
	echo "│ $branchName │ $sync │"
	echo "└─${branchName//?/─}─┴─${sync//?/─}─┘"
	tput sgr 0
	echo
}

function get_files
{
	ADD_FILES=$(git diff --cached --name-status)
	# NO_FILES=$(git diff --name-status)

	temp=$(for word in $ADD_FILES; do echo $word; done)
	FILES=(${temp})

	i=1
	while [ "$i" -lt "${#FILES[@]}" ]; do
		if [ "${FILES[$(($i - 1))]}" == "M" ]; then
			changeType+=("\033[1;33m●\033[0m")
		elif [ "${FILES[$(($i - 1))]}" == "A" ]; then
			changeType+=("\033[1;32m+\033[0m")
		elif [ "${FILES[$(($i - 1))]}" == "D" ]; then
			changeType+=("\033[1;31m-\033[0m")
		else
			changeType+=("\033[1;33m?\033[0m")
		fi 

		fileName+=(${FILES[$i]})
		selected+=( true )

		i=$(($i + 2))
	done

	length=${#fileName[@]}
}

function toggle_file
{
	if [ ${selected[$selectionIndex]} = true ]; then
		selected[$selectionIndex]=false
		git reset ${fileName[$selectionIndex]}
	else
		selected[$selectionIndex]=true
		git add ${fileName[$selectionIndex]}
	fi
}

function print_menu
{
	for (( i=0; i<${#fileName[@]}; i++ ));
	do
		if [ $i == $selectionIndex ]; then
			printf "\033[7m"
			if [ ${selected[$i]} = true ]; then
				printf " ✓   "
			else
				printf "     "
			fi
			temp=$( echo ${changeType[$i]} | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')
			printf "$temp ${fileName[$i]}  \033[0m\n"
		else
			if [ ${selected[$i]} = true ]; then
				echo " ✓   ${changeType[$i]} ${fileName[$i]} "
			else
				echo "     ${changeType[$i]} ${fileName[$i]} "
			fi
		fi
	done

	echo
}

function commit
{
	# startup
	git fetch
	git add .
	sync=$(go_fetch)
	branchName=$(get_branch)
	get_files
	selectionIndex=$length


	while [ $breakOut = true ]; do
		# draw ui
		clear
		draw_top_box
		print_menu

		if [ $length == $selectionIndex ]; then
			printf "\033[7m[  COMMIT  ]\033[0m\n"
		else
			echo "[  COMMIT  ]"
		fi

		#handel input
		while true; do
			read -rsn1 esc
			if [ "$esc" == $'\033' ]; then
				read -sn1 bra
				read -sn1 typ
			elif [ "$esc" == "" ]; then
				if [ $length == $selectionIndex ]; then
					breakOut=false
				else
					toggle_file 
				fi
				break
			fi
			if [ "$esc$bra$typ" == $'\033'[A ]; then
				selectionIndex=$(($selectionIndex - 1))
				if [ "$selectionIndex" -lt "0" ]; then
					selectionIndex=$length
				fi
				break
			elif [ "$esc$bra$typ" == $'\033'[B ]; then
				selectionIndex=$(($selectionIndex + 1))
				if [ "$selectionIndex" -gt "$length" ]; then
					selectionIndex=0
				fi
				break
			fi
		done
	done

	clear
	draw_top_box
	print_menu
	read -p " >>  " input

	if [ "$input" = "" ]; then
		clear
		draw_top_box
		print_menu
		printf "\033[1;31mCommit aborted\033[0m\n"
		exit
	fi

	git commit -m "$input"
	clear
	echo "Commiting..."
	status
}

function status
{
	git fetch
	git add .
	branchName=$(get_branch)
	sync=$(go_fetch)
	fileName=()
	changeType=()
	selected=()
	get_files
	selectionIndex=$length
	clear
	draw_top_box
	print_menu
}

function discard
{
	echo "coming soon!"
}

function ignore
{
	echo "coming soon!"
}

function branch
{
	echo "coming soon!"
}

function push_it
{
	echo "Pushing..."
	git push
	branchName=$(get_branch)
	sync=$(go_fetch)
	fileName=()
	changeType=()
	selected=()
	get_files
	selectionIndex=$length
	clear
	draw_top_box
	print_menu
}

function show_help
{
	echo
	tput setaf 7
	echo "┌───────────────────────────────────────────────────┐"
	echo "│ Help:                                             │"
	echo "│                                                   │"
	echo "│ jit branch    ## select branch                    │"
	echo "│ jit b         ## shorthand                        │"
	echo "│                                                   │"
	echo "│ jit commit    ## opens commit interface           │"
	echo "│ jit c         ## shorthand                        │"
	echo "│                                                   │"
	echo "│ jit discard   ## select files to discard changes  │"
	echo "│ jit d         ## shorthand                        │"
	echo "│                                                   │"
	echo "│ jit ignore    ## select files to ignore           │"
	echo "│ jit i         ## shorthand                        │"
	echo "│                                                   │"
	echo "│ jit push      ## push changes                     │"
	echo "│ jit p         ## shorthand                        │"
	echo "└───────────────────────────────────────────────────┘"
	tput sgr 0
	echo
}


# handle arguments

if [ "$#" -lt "1" ]; then
	status
elif [ "$1" = "status" ] || [ "$1" = "s" ]; then
	status
elif [ "$1" = "branch" ] || [ "$1" = "b" ]; then
	branch
elif [ "$1" = "commit" ] || [ "$1" = "c" ]; then
	commit
elif [ "$1" = "discard" ] || [ "$1" = "d" ]; then
	discard
elif [ "$1" = "ignore" ] || [ "$1" = "i" ]; then
	ignore
elif [ "$1" = "push" ] || [ "$1" = "p" ]; then
	push_it
elif [ "$1" = "help" ] || [ "$1" = "h" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	show_help
else
	show_help
fi

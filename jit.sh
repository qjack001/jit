#!/bin/bash

# TODO:
# add checks for failed commits, pushes, etc
# check that branches & filepaths work properly

fileName=()
changeType=()
selected=()
selectionIndex=0
length=0
branchName=""
sync=""
breakOut=true

branches=()
numBranches=0

function get_branch
{
	if [[ $(git rev-parse --abbrev-ref HEAD) == "" ]]; then
		echo "Not a repo"
		exit
	fi
	echo $(git rev-parse --abbrev-ref HEAD)
}

function go_fetch
{
	VALUES=$(git rev-list --left-right --count "$branchName...origin/$branchName")
	val=($VALUES)

	# ⇩ ⇧  ↑ ↓
	
	if [[ "${val[0]}" == "0" ]]; then
		if [[ "${val[1]}" == "0" ]]; then
			echo "Up-to-date"
		else
			echo "${val[1]} ↓"
		fi
	else
		if [[ "${val[1]}" == "0" ]]; then
			echo "${val[0]} ↑"
		elif [[ "${val[1]}" == "" ]]; then
			echo "publish ↑"
		else
			echo "${val[1]} ↓   ${val[0]} ↑"
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

function get_branches
{
	ALL_BRANCHES=$(git for-each-ref refs/heads/ --format='%(refname)') # --sort=-committerdate ## sort last committed to first
	searchstring="refs/heads/"

	for branch in $ALL_BRANCHES; do
		temp=${branch#*$searchstring}
		branches+=($temp)
	done

	numBranches=${#branches[@]}
}

function get_files
{
	ADD_FILES=$(git diff --cached --name-status --no-renames) # -M100% -C100%  ## turns rename and copy detection back on, but to 100%
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
		elif [ "${FILES[$(($i - 1))]}" == "C100" ]; then
			changeType+=("\033[1;32mC\033[0m")
			i=$(($i + 1))
		elif [ "${FILES[$(($i - 1))]}" == "R100" ]; then
			changeType+=("\033[1;33mR\033[0m")
			i=$(($i + 1))
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

function deselect_all
{
	for (( i=0; i<$length; i++ )); do
		selectionIndex=$i
		toggle_file 
	done
	selectionIndex=$length
}

function discard_selected_files
{
	for (( i=0; i<${#fileName[@]}; i++ ));
	do
		if [ ${selected[$i]} = true ]; then
			if [ ${changeType[$i]} = "\033[1;32m+\033[0m" ]; then
				unlink ${fileName[$i]}
			else
				git reset HEAD ${fileName[$i]}
				git checkout -- ${fileName[$i]}
			fi
		fi
	done
}

function ignore_selected_files
{
	touch ".gitignore"
	for (( i=0; i<${#fileName[@]}; i++ ));
	do
		if [ ${selected[$i]} = true ]; then
			echo ${fileName[$i]} >> ".gitignore"
			git reset HEAD ${fileName[$i]}
		fi
	done
}

function switch_branch
{
	git checkout "${branches[$selectionIndex]}"
}

function print_branch_menu
{
	for (( i=0; i<${#branches[@]}; i++ ));
	do
		if [ $i == $selectionIndex ]; then
			printf "\033[7m  ${branches[$i]}  \033[0m\n"
		else
			printf "  ${branches[$i]}  \n"
		fi
	done

	echo
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
			temp=$( echo ${changeType[$i]} | sed -E 's/\\033\[.{1,8}m//g' )
			# $( echo ${changeType[$i]} | tr -d '[:cntrl:]' )
			printf -- "$temp ${fileName[$i]}  \033[0m\n"
		else
			if [ ${selected[$i]} = true ]; then
				printf " ✓   ${changeType[$i]} ${fileName[$i]} \n"
			else
				printf "     ${changeType[$i]} ${fileName[$i]} \n"
			fi
		fi
	done

	if [ ${#fileName[@]} == 0 ]; then
		tput setaf 7
		printf " \033[3mNo changed files\033[0m\n"
		tput sgr 0
	fi

	echo
}

function commit
{
	# startup
	git fetch
	git add .
	branchName=$(get_branch)
	sync=$(go_fetch)
	get_files
	selectionIndex=$length

	while [ $breakOut = true ]; do
		# draw ui
		clear
		draw_top_box
		print_menu

		if [ ${#fileName[@]} == 0 ]; then
			exit
		fi

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

	clear
	draw_top_box
	echo "Commiting..."
	git commit -m "$input"
	clear
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
	# startup
	git fetch
	git add .
	branchName=$(get_branch)
	sync=$(go_fetch)
	get_files
	deselect_all

	while [ $breakOut = true ]; do
		# draw ui
		clear
		draw_top_box
		print_menu

		if [ ${#fileName[@]} == 0 ]; then
			exit
		fi

		if [ $length == $selectionIndex ]; then
			printf "\033[7m[  DISCARD  ]\033[0m\n"
		else
			echo "[  DISCARD  ]"
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
	read -p " Are you sure? (y/n)  " input

	if [ "$input" = "y" ]; then
		clear
		draw_top_box
		echo "Discarding..."
		discard_selected_files
		status
		exit
	fi

	clear
	draw_top_box
	print_menu
	printf "\033[1;31mDiscard aborted\033[0m\n"
}

function ignore
{
	# startup
	git fetch
	git add .
	branchName=$(get_branch)
	sync=$(go_fetch)
	get_files
	deselect_all

	while [ $breakOut = true ]; do
		# draw ui
		clear
		draw_top_box
		print_menu

		if [ ${#fileName[@]} == 0 ]; then
			exit
		fi

		if [ $length == $selectionIndex ]; then
			printf "\033[7m[  IGNORE  ]\033[0m\n"
		else
			echo "[  IGNORE  ]"
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
	read -p " Are you sure? (y/n)  " input

	if [ "$input" = "y" ]; then
		clear
		draw_top_box
		echo "Ignoring..."
		ignore_selected_files
		status
		exit
	fi

	clear
	draw_top_box
	print_menu
	printf "\033[1;31mIgnore aborted\033[0m\n"
}

function branch
{
	git fetch
	branchName=$(get_branch)
	sync=$(go_fetch)
	get_branches

	selectionIndex=$numBranches

	for i in "${!branches[@]}"; do
		if [[ "${branches[$i]}" = "${branchName}" ]]; then
			selectionIndex=$i
		fi
	done

	while [ $breakOut = true ]; do
		# draw ui
		clear
		draw_top_box
		print_branch_menu

		if [ $numBranches == $selectionIndex ]; then
			printf "\033[7m[  NEW BRANCH  ]\033[0m\n"
		else
			echo "[  NEW BRANCH  ]"
		fi

		#handel input
		while true; do
			read -rsn1 esc
			if [ "$esc" == $'\033' ]; then
				read -sn1 bra
				read -sn1 typ
			elif [ "$esc" == "" ]; then
				if [ $numBranches == $selectionIndex ]; then
					breakOut=false
				else
					switch_branch
					clear
					status
					exit
				fi
				break
			fi
			if [ "$esc$bra$typ" == $'\033'[A ]; then
				selectionIndex=$(($selectionIndex - 1))
				if [ "$selectionIndex" -lt "0" ]; then
					selectionIndex=$numBranches
				fi
				break
			elif [ "$esc$bra$typ" == $'\033'[B ]; then
				selectionIndex=$(($selectionIndex + 1))
				if [ "$selectionIndex" -gt "$numBranches" ]; then
					selectionIndex=0
				fi
				break
			fi
		done
	done

	clear
	draw_top_box
	print_branch_menu
	read -p " >>  " input

	if [ "$input" = "" ]; then
		clear
		draw_top_box
		print_branch_menu
		printf "\033[1;31mCreate branch aborted\033[0m\n"
		exit
	fi

	# clean-up input for branch naming
	cleaned=${input//[_+=.,~^:\"\'!]}
	branchTitle=$( echo $cleaned | tr ' ' '-' )
	while true; do
		if [[ $branchTitle = -* ]]; then
			branchTitle=${branchTitle#?};
		else
			break
		fi
	done

	git checkout -b "$branchTitle" "$branchName"
	clear
	draw_top_box
	echo "Creating new $input branch..."
	status
}

function push_it
{
	branchName=$(get_branch)
	sync=$(go_fetch)
	clear
	draw_top_box
	echo "Pushing..."
	git push
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

function pull_it
{
	branchName=$(get_branch)
	sync=$(go_fetch)
	clear
	draw_top_box
	echo "Pulling..."
	git pull
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

function publish
{
	branchName=$(get_branch)
	sync=$(go_fetch)
	clear
	draw_top_box
	echo "Publishing..."
	git push -u origin "$branchName"
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

function revert
{
	if [ "$#" -lt "1" ]; then
		git revert --no-commit HEAD~1..
	else
		git revert --no-commit "HEAD~$1.."
	fi

	commit
}

function cancel_push
{
	git reset HEAD^
	status
}

function show_help
{
	clear
	tput setaf 7
	echo "┌───────────────────────────────────────────────────┐"
	echo "│ Help:                                             │"
	echo "│                                                   │"
	echo "│ jit branch      ## select branch                  │"
	echo "│                                                   │"
	echo "│ jit commit      ## opens commit interface         │"
	echo "│                                                   │"
	echo "│ jit discard     ## select files & discard changes │"
	echo "│                                                   │"
	echo "│ jit ignore      ## select files to ignore         │"
	echo "│                                                   │"
	echo "│ jit publish     ## publish new branch             │"
	echo "│                                                   │"
	echo "│ jit push        ## push changes                   │"
	echo "│ jit cancel-push ## cancel unpushed commit         │"
	echo "│                                                   │"
	echo "│ jit pull        ## pull changes                   │"
	echo "│                                                   │"
	echo "│ jit revert <#>  ## revert back '#' commits        │"
	echo "│                 ## reverts last if no # is given  │"
	echo "│                                                   │"
	echo "│ jit short       ## show shortforms of commands    │"
	echo "│                                                   │"
	echo "│ jit update      ## update to the latest version   │"
	echo "└───────────────────────────────────────────────────┘"
	tput sgr 0
	echo
}

function update
{
	branchName=$(get_branch)
	sync=$(go_fetch)
	clear
	draw_top_box
	echo "Updating..."
	curl -H 'Cache-Control: no-cache' "https://raw.githubusercontent.com/qjack001/jit/master/jit.sh?$(date +%s)" -o new-jit.sh
	mv -f 'new-jit.sh' '/usr/local/bin/jit'
	chmod +x '/usr/local/bin/jit'
	echo "Updated!"
	echo
}

function install
{
	cp -f 'jit.sh' '/usr/local/bin/jit'
	chmod +x '/usr/local/bin/jit'
}


# handle arguments

if [ "$#" -lt "1" ]; then
	status
elif [ "$1" = "status" ] || [ "$1" = "s" ] || [ "$1" = "--status" ] || [ "$1" = "-s" ]; then
	status
elif [ "$1" = "branch" ] || [ "$1" = "b" ] || [ "$1" = "--branch" ] || [ "$1" = "-b" ]; then
	branch
elif [ "$1" = "commit" ] || [ "$1" = "c" ] || [ "$1" = "--commit" ] || [ "$1" = "-c" ]; then
	commit
elif [ "$1" = "discard" ] || [ "$1" = "d" ] || [ "$1" = "--discard" ] || [ "$1" = "-d" ]; then
	discard
elif [ "$1" = "ignore" ] || [ "$1" = "i" ] || [ "$1" = "--ignore" ] || [ "$1" = "-i" ]; then
	ignore
elif [ "$1" = "install" ] || [ "$1" = "--install" ]; then
	install
elif [ "$1" = "pull" ] || [ "$1" = "--pull" ]; then
	pull_it
elif [ "$1" = "push" ] || [ "$1" = "p" ] || [ "$1" = "--push" ] || [ "$1" = "-p" ]; then
	push_it
elif [ "$1" = "cancel-push" ] || [ "$1" = "--cancel-push" ] || [ "$1" = "cancel" ]; then
	cancel_push
elif [ "$1" = "publish" ] || [ "$1" = "pub" ] || [ "$1" = "--publish" ] || [ "$1" = "-pub" ]; then
	publish
elif [ "$1" = "revert" ] || [ "$1" = "r" ] || [ "$1" = "--revert" ] || [ "$1" = "-r" ]; then
	revert $2
elif [ "$1" = "update" ] || [ "$1" = "--update" ]; then
	update
elif [ "$1" = "help" ] || [ "$1" = "h" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	show_help
else
	show_help
fi

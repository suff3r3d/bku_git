#!/bin/bash

##################################################################################
#
#
#
# - .bku
#   - commit_history
#   - tracked_files
#   - commits/
#     - $(hashes of files) # (hash of name if first commit)
#       - (original file if first commit)
#       - commit_message
#       - next_diff # stores differences from current to next (newer) (created by diff)
# 			- prev_diff
#       - next_hash # hash of next commit
#
#
##################################################################################

# Restoring files copy previous version

###########################  Utilities  ##########################################
hash_with_date() {
	echo "$1$(date +%s)" | sha256sum | cut -d ' ' -f 1
}

hash_file() {
	sha256sum $1 | cut -d ' ' -f 1
}

hash_filename() {
	echo "$1" | sha256sum | cut -d ' ' -f 1
}

get_latest_directory() {
	dir_path=$1
	ls -d "$dir_path"/*/ 2>/dev/null | xargs -I{} stat --format '%W %n' {} | sort -n | tail -n 1 | cut -d ' ' -f 2
}

get_latest_created_file() {
	dir_path=$1
	ls -t "$dir_path" 2>/dev/null | head -n 1
}

remove_prefix() {
	filepath=$1
	if [[ "$filepath" == ./* ]]; then
		filepath=${filepath:2}
	fi
	echo "$filepath"
}

##################################################################################

if [ "$1" == "init" ]; then
	if [ -d ".bku" ]; then
  	echo "Error: Backup already initialized in this folder."
  	exit 1
	fi

  mkdir .bku

  touch .bku/commit_history
  printf "$(date +"%H:%M-%d/%m/%Y"): BKU Init.\n" >> ".bku/commit_history"

	touch .bku/tracked_files

	mkdir .bku/commits
	mkdir .bku/commit_id

  echo "Backup initialized."
fi

add() {
	filepath=$1

	if [ ! -d .bku ]; then
		echo ".bku directory doesn't exist."
		exit 1
  fi

	if [ -d "$filepath" ]; then
		echo "$filepath is a directory".
		exit 1
	fi

	if [ ! -f "$filepath" ]; then
		echo "Error: $filepath doesn't exist."
		exit 1
	fi

	if [ "$(strings .bku/tracked_files | grep $filepath)" != "" ]; then
		echo "Error: $filepath is already tracked."
		exit 1
	fi

	printf "$filepath" >> .bku/tracked_files
	# hash_dir=.bku/commits/$(echo "$filepath" | sha256sum | cut -d ' ' -f 1)
	hash_dir=.bku/commits/$(hash_filename "$filepath")
	mkdir $hash_dir
	cp $filepath $hash_dir/original
	echo $(hash_filename $filepath) >> $hash_dir/commit_logs

	echo "Added $filepath to backup tracking."
}

commit_file() {
	message=$1
	filepath=$2
	id=$3

	if [ ! -f "$filepath" ]; then
		echo "Error: $filepath doesn't exist."
		exit 1
	fi

	if [ "$(strings .bku/tracked_files | grep $filepath)" == "" ]; then
		echo "Error: $filepath hasn't been tracked yet."
		exit 1
	fi

	latest_hash_dir=.bku/commits/$(tail -n 1 .bku/commits/$(hash_filename $filepath)/commit_logs)
	tmp_directory=$(recreate $filepath)

	if [[ ! -f "$tmp_directory/required_file" ]]; then
		echo "WHATTTT"
		exit 1
	fi

	if cmp -s "$tmp_directory/required_file" "$filepath"; then
		echo "Error: $filepath is the same as the latest commit."
		exit 1
	fi

	current_hash_file=$(hash_with_date "$filepath")
	current_hash_dir=.bku/commits/$current_hash_file
	mkdir $current_hash_dir

	# touch $latest_hash_dir/next_diff
	# touch $latest_hash_dir/next_hash
	diff "$tmp_directory/required_file" "$filepath" > $latest_hash_dir/next_diff
	diff "$filepath" "$tmp_directory/required_file" > $current_hash_dir/prev_diff
	printf "$current_hash_file" > $latest_hash_dir/next_hash
	echo "$message" > $current_hash_dir/commit_message

	echo "$current_hash_file" >> .bku/commits/$(hash_filename $filepath)/commit_logs

	# echo "$(date +"%H:%M-%d/%m/%Y"): $message ($filepath)." > .tmp/tmp_history
	# cat .bku/commit_history >> .tmp/tmp_history
	# cp .tmp/tmp_history .bku/commit_history

	echo "$filepath" >> ".bku/commit_id/$id"
}

recreate() {
	# recreate a file to the latest commit

	# using hash value to recreate 
	filepath=$1

	current_hash_file=$(hash_filename "$filepath")
	current_hash_dir=.bku/commits/$current_hash_file

	# create a temp directory and work in it for security
	tmp_directory=$(mktemp -d)
	if [[ $tmp_directory == "" ]]; then
		exit 1
	fi

	current_file=$current_hash_dir/original
	cp $current_file $tmp_directory/current_file
	current_file=$tmp_directory/current_file

	while [[ -f $current_hash_dir/next_hash ]] ; do
		patch -N $current_file $current_hash_dir/next_diff 1>/dev/null 2>/dev/null

		current_hash_file=$(cat "$current_hash_dir/next_hash")
		current_hash_dir=.bku/commits/$current_hash_file
	done

	mv $current_file $tmp_directory/required_file

	printf "$tmp_directory" # return hash dir
	# now the latest is $current_file (# .tmp/latest)
}

restore_file() {
	filepath=$1

	tmp_directory=$(recreate $filepath)
	current_hash_dir=.bku/commits/$(tail -n 1 .bku/commits/$(hash_filename $filepath)/commit_logs)

	if [[ ! -e "$current_hash_dir/prev_diff" ]]; then
		echo "Error: No previous version available for $filepath"
		exit 1
	fi

	patch -N "$tmp_directory/required_file" "$current_hash_dir/prev_diff" 2> /dev/null
	mv $tmp_directory/required_file "./$filepath"

	echo "Restored $filepath to its previous version."
}

restore_latest_commit() {
	if [ -z "$( ls -A '.bku/commit_id' )" ]; then
		echo "Error: No file to be restored."
		exit 0
	fi

	list_file=$(get_latest_created_file ".bku/commit_id")

	while IFS= read -r line; do
		echo "Commiting file $line"
		restore_file $line
		# Add your logic here
	done < ".bku/commit_id/$list_file"
}

########################### Main ################################

if [ ! -d ".bku" ]; then
	echo ".bku directory doesn't exist!"
	exit 1
fi

if [ "$1" == "add" ]; then
  filepath=$2
	filepath=$(remove_prefix $filepath)

  if [ "$2" == "" ]; then
    echo "Add all files."
		exit 0
  fi
	add $filepath
	exit 0
fi

if [ "$1" == "diff" ]; then
	if [ "$2" == "" ]; then
		echo "Diff all files."
		exit 0
	fi
fi

if [ "$1" == "commit" ]; then
	message=$2
  filename=$3
	id=$(echo "$(date +%s)")

  if [ "$filename" == "" ]; then
		list_of_files=""

		dir_path="."
		find "$dir_path" -type f | while IFS= read -r file; do
			file=$(remove_prefix $file)
			if [[ $file == .bku/* ]]; then
				continue
			fi

			if [[ $file == bku.sh ]]; then
				continue
			fi

			tmp_directory=$(recreate $file)
			if ! cmp -s "$tmp_directory/required_file" $file; then
				$(commit_file $message $file $id) == 0 && echo "Committed $file with ID $(date +"%H:%M-%d/%m/%Y")." && list_of_files="$list_of_file,$file"
			fi  
			# Add your logic here
		done

		if [[ $(cat .bku/commit_id/$id 2> /dev/null) == "" ]]; then
			echo "No file committed"
		fi

		exit 0
  fi

	commit_file $message $filename
	exit 0
fi

if [ "$1" == "restore" ]; then
	if [ "$2" == "" ]; then
		# echo "Restore latest commit."
		restore_latest_commit
		exit 0
	fi

	filepath=$2
	filepath=$(remove_prefix $filepath)
	restore_file $filepath
fi

if [ "$1" == "history" ]; then
	cat .bku/commit_history
fi

if [ "$1" == "schedule" ]; then
	CRON_JOB=""
	if [ "$2" == "--daily" ]; then
		CRON_JOB=""
	fi
fi

if [ "$1" == "stop" ]; then
	if [ ! -d .bku/ ]; then
		echo "Error: No backup system to be removed."
		exit 1
	fi

	rm -rf .bku
	echo "Backup system removed."
fi
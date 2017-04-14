#!/bin/bash
# A script which stores your gnome-terminal profiles in a tar archive which can get restored

COMMAND=$1
# --- Create backup ---
if [ "$COMMAND" == "backup" ]
then
	BACKUPNAME=$2
	# Leave script if there was no backup name specified
	if [ "$BACKUPNAME" == "" ]
	then
		echo "No backup name specified. No backup created"
		exit 0;
	fi
	# The id of the profile and the related .dconf file, where the profile settings are backuped in, are stored in this file
	indexFileName="profile_indexes"

	# Get all terminal profile ids in format [:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx]
	ids=$(dconf dump /org/gnome/terminal/legacy/profiles:/ | grep -e "\[\:")

	cnt=0
	# Append all created backups filenames to this string, so we now later what we have to pack with tar
	profileBackupFiles=""
	# loop over all ids
	for id in $ids
	do
		# Remove the '[' part in the id (first character)
		id=${id:1}
		# Remove the ']' part in the id (last character)
		id=${id%?}
	
		# Get the visible name of the profile from given id in format visible-name='name' (if the visible-name contains a "'" it is in format visible-name="name")
		name=$(dconf dump /org/gnome/terminal/legacy/profiles:/$id/ | grep -e "visible-name")
		# Remove visbile-name=' (First 14 characters) part of the string
		name=${name:14}
		# Remove last char (') from string
		name=${name%?}
		# The filename shout be the visible-name of the profile with a .dconf extension
		fileName="$name.dconf"
		# Save profile data in file
		dconf dump /org/gnome/terminal/legacy/profiles:/$id/ > $fileName
		# Add created backup filename to var
		profileBackupFiles="$profileBackupFiles $fileName"
		# Add id and the related filename to indexFileName so we now later which .dconf backup file relates to the id use "<==>" as delimiter
		echo "\"$id\"<==>\"$fileName\"" >> $indexFileName

		((cnt++))
	done
	echo $createdFiles
	if [ "$cnt" -ne "0" ]; then
		tar -cf $BACKUPNAME $indexFileName $profileBackupFiles --remove-files
		echo "$cnt profiles saved and stored in $BACKUPNAME"
	else
		echo "Nothing to backup"
	fi
# --- Restore backup ---
elif [ "$COMMAND" == "restore" ]
then
	# A script which restores your gnome-terminal profile backups

	BACKUPNAME=$2
	# Leave script if there was no backup name specified
	if [ "$BACKUPNAME" == "" ]
	then
		echo "No backup name specified. No backup restored."
		exit 0;
	fi

	indexFileName="profile_indexes"
	# Extract index file direct in variable (as string)
	indexes=$(tar -xf $BACKUPNAME $indexFileName -O)

	# Loop over indexes
	for index in $indexes
	do
		echo "#############"
		echo $index
		# Split index string in id and filename by its delimiter '<==>'
		arr=(${index//<==>/ })
		id=${arr[0]}
		fileName=${arr[1]}
	
		# Remove the qoutes from the beginning and the end of the string	
		id=${id:1}
		fileName=${fileName:1}
		# Remove last char (') from string
		id=${id%?}
		fileName=${fileName%?}
	
		# Load profile backup file
		#profileData=$(tar -xf $BACKUPNAME $fileName -O)
		tar -xf $BACKUPNAME $fileName
		#echo $profileData > "tmpfile.dconf"

		echo $profileData
		# Restore profile data
		$(dconf load /org/gnome/terminal/legacy/profiles:/$id/ < $fileName)
		rm $fileName

		#actualListEntries=$( dconf read /org/gnome/terminal/legacy/profiles:/list)
		echo "#############"
	done

	# Add all ids to the list key of /org/gnome/terminal/legacy/profiles:/, but first load all sub ids (So we can add them to the key later)
	listedIDs=$(dconf list /org/gnome/terminal/legacy/profiles:/)
	listIdStr="["
	for listId in $listedIDs
	do
		# Check if listId is a sub dir
		if [ "${listId: -1}" == "/" ]
		then
			listId=${listId:1}
			listId=${listId%?}
			# If there was no id added, there is no need to add a ','
			if [ ${#listIdStr} == "1" ]
			then
				listId="'$listId'"
			else
				listId=",'$listId'"
			fi
			
			listIdStr="$listIdStr$listId"
			echo $listId
		fi
	done
	listIdStr="$listIdStr]"
	echo $listIdStr
	# Set list value
	dconf write /org/gnome/terminal/legacy/profiles:/list $listIdStr
# --- Nothing to do ---
else
	echo "No command specified. Use backup for crearing a backup or restore for restoring a backup"
	exit 0;
fi

#!/bin/bash 

# DBCompare Script
# Chris Halbersma 11/25/2015
# Implementing a Best Practice

while getopts "c:h" OPTIONS; do
    case $OPTIONS in
        c) config_file=${OPTARG};;
        h) help; cleanup_exit 0;;
    esac
done

if [[ $config_file == "" ]] ; then
    # No Config File
    echo -e  "Error: Comparison Requires a Config File" 
    exit 1
elif ! [[ -r $config_file ]] ; then
    # Config File Doesn't Exist or isn't readable
    echo -e "Error : Config File either Doesn't Exist or Isn't Readable" 
    exit 1
else
    # Config File Exists and Is Readable so Read It.
    echo -e "MESSAGE : Loading Config File" 
    . $config_file
fi

# Set Host Name
if [ -z "$alt_host" ]; then
    # Custom Host Not Set
    echo -e "MESSAGE : Seting Repo Host to $(hostname --fqdn)"
    repo_host=$(hostname --fqdn)
else
    # Custom Host Set
    echo -e "MESSAGE : Setting Repo Host to Customized alt_host, $alt_host "
    repo_host=$alt_host
fi

function mail_me() {
    # $1 Msg File
    echo -e "MESSAGE : User $user being emaild at email $notify_email about Schema Change"
    cat $1 | tr -d \\r | mailx -s "A schema has been changed on $repo_host. Please Review (and beat if neccessary)" $notify_email 
}

# Create the Temp Dir
mkdir -p $tmp_dir
cd $tmp_dir
files_to_clean=$(find . | grep \.sql | wc -l )
if [[ $files_to_clean -eq 0 ]]; then
    # We're okay
    echo "Message : Nothing to Clean Continuing"
else
    # Clean Stuff
    echo "Message : $files_to_clean number of files to clean"
    rm $tmp_dir/*/*.sql
fi

# Grab the Latest In the Repository
echo -e "MESSAGE : Pulling down the full latest"
# Move to Repo Location
cd $local_repo_location

# Check if it's a Git Dir
git rev-parse --git-dir
is_git_dir=$?

# If 
if [[ $is_git_dir -eq 0 ]] ; then
    # Were in a Git Dir
    # Reset to Latest Commit
    git reset --hard HEAD
    git clean -dfx
    git pull
else 
    ## We're not in a Git dir
    echo -e "ERROR : $(pwd) is not a git directory"
    exit 2
fi

# Parse Databases
all_database_array=$(mysql -sN -u $database_user --password=$database_password -e "select schema_name FROM information_schema.schemata where schema_name not in($ignored_database_list);")
is_dbl_okay=$?

if [[ is_dbl_okay -eq 0 ]] ; then
    # Continue
    for indv_database in $all_database_array
    do
        # Pull Schema
        cd $tmp_dir
        mkdir -p $indv_database
        cd ${tmp_dir}/${indv_database}
        # Do the Dump for $indv_database
        mysqldump   --compact --skip-opt --skip-lock-tables --skip-comments \
                    --routines --user=${database_user} --password=${database_password} \
                    -d --tab=${tmp_dir}/${indv_database} ${indv_database} > ${tmp_dir}/${indv_database}/${indv_database}-routines.sql
        is_dump_okay=$?
        if [[ is_dump_okay -eq 0 ]]; then
            # Dump Okay
            echo "MESSAGE : Dump of database $indv_database schema and routines has completed"
        else
            echo "ERROR : Dump of database $indv_database schema and routines has completed. But it failed."
            > $tmp_message_file
            echo "ERROR : Dump of database $indv_database schema and routines has completed. But it failed." > $tmp_message_file
            echo "Chances are that there's an issue with a definer on one of the views or routines (looking at you htorres)" >> $tmp_message_file
            # Bad because hard code
            echo "Echoing Logfile Back to you (Should contain the mysqldump error): " >> $tmp_message_file
            cat $log_file | tail -n 20 >> $tmp_message_file
            mail_me $tmp_message_file
            exit 2
        fi
    done
else
    echo -e "ERROR : Was not able to pull the list of databases"
    exit 3
fi

# Now Move And Commit
# I really should build this into the process, however I'm going to take a shortcut here. Future me is going to hate me
cd ${local_repo_location}/${host_environment}
mkdir -p ${repo_host}
cd ${local_repo_location}/${host_environment}/${repo_host}
# Remove the old copy
rm -r ${local_repo_location}/${host_environment}/${repo_host}/*

cp -r ${tmp_dir}/* ${local_repo_location}/${host_environment}/${repo_host}

cd ${local_repo_location}/${host_environment}/${repo_host}

# Add New Files
git add -u ${local_repo_location}/${host_environment}/${repo_host}
git add ${local_repo_location}/${host_environment}/${repo_host}/.

git diff-index --quiet HEAD
is_changes=$?

function table_data(){
    # $1 Commit Number
    new_table_number=$(git show ${commit_number} | grep CREATE\ TABLE | wc -l)
    if [[ new_table_number -eq 0 ]]; then
        # No New Tables
        echo -e "New Table Summary: No New Tables." >> $tmp_message_file
    else
        if [[ new_table_number -gt 5 ]]; then
            # New Table Summary GT 5
            echo -e "New Table Summary. ${new_table_number} of new tables created. Showing first 5" >> $tmp_message_file
        else
           # New Table Summary is 0-5
           echo -e "New Table Summary. ${new_table_number} of new tables created." >> $tmp_message_file
        fi
        # No Matter what print the first 5 tables
        tables=$(git show ${commit_number} | grep CREATE\ TABLE | head -n 5 | tr -d \(\`\+ | cut -f 3 -d \  )
        printf %s "${tables[@]}" >> $tmp_message_file
    fi
}


if [[ $is_changes -eq 1 ]] ; then
    # Changes to Commit
    echo -e "MESSAGES : Changes to Commit"
    git commit -a -m "Commit by ${repo_host} (automated Process) with new Schema Changes"
    
    # Pushing Changes
    echo -e "MESSAGES : Pushing Changes to Repo"
    git push
    
    # Grabbing Commit Number
    commit_number=$(git rev-parse HEAD)
    
    # Build Send Message
    # Clean Messsage File
    > $tmp_message_file
    echo -e "" >> $tmp_message_file
    echo -e "DBCompare Schema Changes Detected on Database Server ${repo_host}." >> $tmp_message_file
    echo -e ":" >> $tmp_message_file
    echo -e "We've detected schema changes in database ${repo_host}." >> $tmp_message_file
    echo -e "You can review the changes graphically (See : ${html_base}${commit_number} )." >> $tmp_message_file
    echo -e ":" >> $tmp_message_file
    echo -e "Summary of Changes" >> $tmp_message_file
    echo -e "::" >> $tmp_message_file
    # Table Summary
    table_data
    echo -e "::" >> $tmp_message_file
    echo -e "Details" >> $tmp_message_file
    git_size=$(git show ${commit_number} | wc -l )
    if [[ $git_size -gt 20 ]] ; then
        ## Git is long
        git show ${commit_number} | head -n 20 >> $tmp_message_file
        echo -e ":"
        echo -e "Log Snipped. First 20 of ${git_size} lines shown." >> $tmp_message_file
        echo -e "Enjoy." >> $tmp_message_file
    else
        ## Git is short
        git show ${commit_number} >> $tmp_message_file
    fi
    
    # Send out the Message
    mail_me $tmp_message_file
    
else
    # No Changes to Commit
    echo -e "MESSAGES : No Changes to Commit"
fi







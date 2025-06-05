 #!/bin/bash

echo "Enter the directory: "
read Target_dir

#Check if the directory is empty 
if [[ -z "$Target_dir" ]];
then
    echo "Usage: /path/to/directory"
    exit 1
fi

Log_dir="logs"
Log_file="$Log_dir/metadata.log"
Valid_regex='^[A-Za-z_][A-Za-z0-9]*=[^\s=#"][^#"]*(\s*#.*)?$'
Blacklisted_keys="^(PATH|PASSWORD|SECRET|TOKEN|EXPORT|export)$" 

# Create log directory and give the respective permission 
mkdir -p "$Log_dir"
if ! id maintainer &>/dev/null ;
then
    sudo useradd -m maintainer
fi

sudo chown maintainer:maintainer "$Log_dir"
sudo chmod 700 "$Log_dir"

touch "$Log_file" # Append data to it 

#Check for env files in the given directory
find "$Target_dir" -type f \( -name "*.env" -o -name ".env.*" \) | while read -r file; 
do 
    echo "Processing: $file"

    Temp_file=$(mktemp)
    Rejected_lines=()
    Valid_count=0
    Invalid_count=0

while IFS= read -r line || [[ -n "$line" ]]; 
do
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^# ]] && continue   # Ignore empty lines and comments

        key=$(echo "$line" | cut -d "=" -f1 | xargs)

        if [[ "$key" =~ $Blacklisted_keys ]];                    # check for blacklisted keys 
        then
            Invalid_count=$((Invalid_count + 1))
            Rejected_lines+=("$line")
            continue
        fi

        if [[ "$line" =~ $Valid_regex ]];                         # Comparing the variable name and the valid regex keys
        then
            echo "$line" >> "$Temp_file"
            Valid_count=$((Valid_count + 1))
        else
            Invalid_count=$((Invalid_count + 1)) 
            Rejected_lines+=("$line")
        fi
    done < "$file"

    Sanitized_file="${file}.sanitized"                                         
    mv "$Temp_file" "$Sanitized_file"                                # Move the contents from the temporary files into the Sanitized file  
    
    Permissions=$(stat -c %a "$file")
    User_Info=$(stat -c "UID=%u (%U) GID=%g (%G)" "$file")
    Last_modified=$(stat -c  "%U %y" "$file")
    ACLS=$(getfacl -p -t "$file" 2>/dev/null | grep -v "^#")
    E_ATTR=$(getfattr -d "$file" 2>/dev/null | grep -v "^#")

    {
        echo "File:$file"
        echo "User:$User_Info"
        echo "Permissions:$Permissions"
        echo "Last_Modified:$Last_modified"
        echo "ACL's':"
        echo "$ACLS"
        echo "Extended_Attributes:"
        echo "$E_ATTR"
        echo "Valid_lines=$Valid_count"
        echo "Invalid_lines=$Invalid_count"
        if (( ${#Rejected_lines[@]} > 0 ));
        then
            echo "Rejected lines from $file: "
            for r in "${Rejected_lines[@]}"; 
            do
                echo "$r"
            done
        fi  
    } >> "$Log_file"

    echo "Cleaned file: $file "
    echo "Sanitized file is stored in $Sanitized_file"

done





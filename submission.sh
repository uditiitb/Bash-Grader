#! /usr/bin/env bash

#chech for required dependencies
depen=(awk python3)

for dep in "${depen[@]}"; do
    if ! command -v "$dep" &> /dev/null; then  #this line checks whether the dependency is present in the present working environment
        echo "Error: $dep is not installed."   #thow error if the dependency is not present in the current environment
        exit 1
    fi
done

#function to combine all the csv files present in the working directory except main.csv  #ho gya*********************************
combine() {
    > main.csv  # clear the main.csv at first
    csv_files=(*csv)  # collecting list of all the csv files in the working directory in an array
    # pop main.csv from the array csv_files as it is not desired
    pop="main.csv"
    index=-1  # initialising index to pop
    for i in "${!csv_files[@]}"; do  # iterate over csv_files indeces
        if [ "${csv_files[$i]}" == "$pop" ]; then  # break the loop when index equals index of main.csv in csv_files
            index=$i
            break
        fi
    done
    # check if the element was found
    if [ "$index" -eq -1 ]; then
        echo "Element '$pop' not found in the array."
    else
        # pop the element at the found index
        popped_element="${csv_files[$index]}"
        csv_files=("${csv_files[@]:0:$index}" "${csv_files[@]:$(($index+1))}")  # setting csv_files from 0 to index-1 and then from index+1 to the last file
    fi
    # getting the length of csv_files
    l=${#csv_files[@]}
    # Initialize the header row for main.csv
    header_row="Roll_Number,Name"
    # iterate over each CSV file and add its base name to main.csv
    for file in "${csv_files[@]}"; do
        header_row+=",$(basename "$file" .csv)"  # this will take the basename of the csv file and make the column name same as that
    done
    # append the header row to main.csv
    echo "$header_row" >> main.csv
    # declarre the array roll_numbers
    declare -a roll_numbers
    # using for loop to read all the roll numbers
    for ((i=0;i<$l;i++)); do
        roll_numbers+="$(awk -F, '{if(NR>1){print tolower($1)}}' "${csv_files[$i]}")"$'\n'  # using tolower to make roll number case-insensitive
    done
    # using sort -u to remove duplicate roll numbers
    roll_numbers=$(echo "${roll_numbers}" | tr '[:upper:]' '[:lower:]' | sort -u)    #tr(translate) unix command used to convert upper to lower
    roll_numbers=$(echo -n "${roll_numbers}")  # -n option allow trailing to the new line
    # iterate over each unique roll number and populate main.csv
    ((count=0))  # I was getting a new line when I declare a new array so I used this method here
    while read -r roll_number; do
        # reading line as roll_numbers
        row="$roll_number,$(awk -F, -v roll="$roll_number" 'NR>1 && tolower($1) == roll {print $2; exit}' "${csv_files[@]}" | head -n 1)"
        for file in "${csv_files[@]}"; do
            # iterating over files in csv_files
            marks=$(awk -F, -v roll="$roll_number" 'NR>1 && tolower($1) == roll {print $3; exit}' "$file")
            row+=","${marks:-a}  # appending the marks of the student to row separated by comma, if marks for that particular roll number is absent in that csv file then this will append 'a' representing absent
        done
        if [ $count != 0 ]; then
            # skip the first row
            echo "$row" >> main.csv  # append row to main.csv
        fi
        ((count=count+1))  # update count=count+1
    done <<< "$roll_numbers"  # read lines from array roll_numbers
}

# Function to upload a new CSV file  #ho gya*****************************************
upload() {
    if [ -n "$1" ]; then      #here -n flag checks whether length of first argument is non-zero
        cp "$1" .             #copy the first argument to the current directory
        echo "File $1 uploaded successfully."
    else
        echo "Usage: bash submission.sh upload <file_path>"
    fi
}

# Function to add a total column to main.csv   #Ho gya***********************************************
total() {
    #create a temporary file
    touch temp

    #checking the last column of the first row of main.csv
    last_column=$(awk 'BEGIN{FS=OFS=","}{if(NR==1){print $NF}}' main.csv)

    #add the total column to main.csv and store it in the temporary file
    awk 'BEGIN {FS=OFS=","} {sub(/[\r\n]+$/,"",$0);if(NR>1){sum=0; for(i=3;i<=NF;i++) sum+=($i=="a"?0:$i);printf("%s,%d\n", $0, sum)} else{print $0}}' main.csv > "temp"
    #append the header 'total' to the last column
    head -n 1 "temp" | awk 'BEGIN {IFS=FS=OFS=","} {$(NF+1)="total"; print $0}' > main.csv
    #aappend other rows includinf the total column from temporary file to main.csv
    tail -n +2 "temp" >> main.csv
    
    #finally remove the temporary file
    rm temp
}

#Function to initialize the remote repo  #ho gya************************************
git_init() {
    #initialising variable remote_dir as first argument of the function call
    remote_dir="$1"
    
    #if the remote_dir does not exist, then create it
    if [ ! -d "$remote_dir" ]; then
        mkdir -p "$remote_dir"     #-p flag to create parent directories if needed
    fi
    
    #create .git_log file in remote repo so that it becomes a check list whether remote repo is initialised with git_init
    touch "$remote_dir/.git_log"    
    #storing the path of remote repo to .git_remote file      
    echo "$remote_dir" > .git_remote      
    echo "Git repository initialized at $remote_dir"
}

#function to commit changes to the remote repo 
git_commit() {
    remote_dir="$(cat .git_remote)"
    commit_message="${@:1}"

    if [ ! -f "$remote_dir/.git_log" ]; then
        echo "Error: Git repository not initialized. Run 'git_init' first."
        return 1
    fi

    #generate a random 16-digit number as the commit hash
    com_hash=$(openssl rand -hex 8)    #openssl rand provide high level of randomness,whereas $RANDOM just generates a pseudo random number ie they are predictable to some extent


    commit_dir="$remote_dir/$com_hash"
    mkdir "$commit_dir"
    cp -r ./* "$commit_dir"

    echo "$com_hash $commit_message" >> "$remote_dir/.git_log"
    echo "Committed changes with hash: $com_hash"
    echo "Commit message: $commit_message"

    # Print the names of modified files
    if [ -n "$(tail -n 1 "$remote_dir/.git_log")" ]; then
        prev_commit=$(tail -n 2 "$remote_dir/.git_log" | head -n 1 |awk '{print $1}')
        diff -qr "$remote_dir/$prev_commit" "$commit_dir"
    else
        echo "No previous commit to compare against."
    fi
}

#function to commit changes to the remote repo using diff and patch commands # ho gya***********************************************8
git_commit_dp() {
    #getting the path to remote repo
    remote_dir="$(cat .git_remote)"
    #initializing variable with the first argument on function call
    com_message="${@:1}"

    #checking whether .git_log exists indirectly checking whether it is the remote repo initialised
    if [ ! -f "$remote_dir/.git_log" ]; then    #-f flag stands for checking the existence for file
        echo "Error:Romote repo not initialized.Run 'git_init' first."
        return 1
    fi

    #generate a random 16-digit number as the commit hash
    com_hash=$(openssl rand -hex 8)    #openssl rand provide high level of randomness,whereas $RANDOM just generates a pseudo random number ie they are predictable to some extent

    com_dir="$remote_dir/$com_hash"
    #create a directory inside remote repo having name as randomly generated 16-digit number
    mkdir "$com_dir"

    #check for any previous commit
    previous_com=$(tail -n 1 "$remote_dir/.git_log" | cut -d ' ' -f 1)   #taking the hash value of previous commit

    #check whether previous commit is non empty
    if [ -n "$previous_com" ]; then
        #if previous commit is non-empty then copy the files from previous commit to the directory of new commit
        cp -r "$remote_dir/$previous_com/"* "$com_dir"    
        #create a patch file which later change the new commit inthe remote repo
        diff -ru "$com_dir" "$(pwd)" > "$com_dir/p.diff"     #-r flag for recursively compare, -u to output a unified diff format
        #patch the files
        patch -s -p1 -d "$com_dir" < "$com_dir/p.diff"     #-d flag for changing the dir to com_dir , -p1 option specifies number of slashes to ignore,in this case 1 slash will be ignored!; -s flag silently patches all the files in the directory without asking any quesrtions
        #remove the p.diff file from remote repo
        rm -f "$com_dir/p.diff"
    else        
        #if previous commit is empty then directly copy all the files from working directory to the folder inside remote repo;-r flag for recursively copying
        cp -r ./* "$com_dir"      
    fi

    #append the commit hash, message to .git_log file
    echo "$com_hash $com_message" >> "$remote_dir/.git_log"
    echo "Committed changes with hash: $com_hash"
    echo "Commit message: $com_message"

    # Print the names of modified files
    if [ -n "$(tail -n 1 "$remote_dir/.git_log")" ]; then
        prev_commit=$(tail -n 2 "$remote_dir/.git_log" | head -n 1 |awk '{print $1}')
        # modified_files=$(diff -qr "$remote_dir/$prev_commit" "$commit_dir" | grep -v '^Only in' | awk -F':' '/Files/ {print $2}' | tr '\n' ' ')
        # if [ -n "$modified_files" ]; then
        #     echo "Modified files: $modified_files"
        # else
        #     echo "No files modified."
        # fi
        diff -qr "$remote_dir/$prev_commit" "$commit_dir"
    else
        echo "No previous commit to compare against."
    fi
}

# Function to checkout a specific commit #ho gya **************************************************************
git_checkout() {
    #read the remote repo directory from .git_remote file
    remote_dir="$(cat .git_remote)"
    #initializing variable with the first argument on function call
    commit_prefix="${@:1}"

    #checking whether .git_log exists indirectly checking whether it is the remote repo initialised
    if [ ! -f "$remote_dir/.git_log" ]; then       #-f flag stands for checking the existence for file
        echo "Error: Git repository not initialized. Run 'git_init' first."
        return 1
    fi

    #using grep command to match prefixes to hash values of commits
    matching_commits=$(grep -E "^$commit_prefix" "$remote_dir/.git_log")         #-E enables to use extended regular expression
    #counting number of matching commits 
    num_matches=$(echo "$matching_commits" | wc -l) 

    #if number of matches is 1,then the prefix is pointing to single hash value
    if [ "$num_matches" -eq 1 ]; then
        #initialising commit_hash as the hash value of desired checkout point
        commit_hash=$(echo "$matching_commits" | awk '{print $1}')
        #initialising commit_dir to the path to the directory of the desired checkout point
        commit_dir="$remote_dir/$commit_hash"
        #if commit_dir exist
        if [ -d "$commit_dir" ]; then
            # Remove all files and directories in the working directory
            rm -rf ./*
            #recursively copy the files from the commit directory to the working directory
            cp -r "$commit_dir/"* .
            echo "Checked out to commit: $commit_hash"
        else
            echo "Error: Commit directory not found."
        fi
    #if prefix is pointing to multiple hash values
    elif [ "$num_matches" -gt 1 ]; then          
        echo "Error: Multiple commits found with the given prefix. Please provide longer prefix."
        #printing the multiple hash values matching
        echo "$matching_commits" | awk '{print "  " $1 " " $2}'
    else
        echo "Error: Commit not found."
    fi
}

# Function to update the marks of specific exam of a student
update() {
    #read roll 
    read -p "Enter student's roll number: " roll_number    #-p flag displays the prompt message
    #read name
    read -p "Enter student's name: " name              
    #read exam name
    read -p "Enter the exam name to be updated: " exam_name          

    #find the column number for given exam name
    exam_col=$(head -n 1 main.csv | tr ',' '\n' | cat -n | grep -w "$exam_name" | cut -f1)   #this first take header of main.csv, replace ',' with new line, number the lines, get the number of the line matching the exam_name,get the number of the file 

    #checking if exam_col is empty
    if [ -z "$exam_col" ]; then
        echo "Error: Exam name '$exam_name' not found in main.csv"
        return 1
    fi
    #update the marks for the given exam in main.csv; /dev/tty  is for waiting for the user input directly from terminal
    awk -v roll="$roll_number" -v name="$name" -v exam_col="$exam_col" '     
        BEGIN {
            FS=OFS=","
        }
        {
            if ($1 == roll) {
                $2 = name
                getline mark < "/dev/tty"         
                $exam_col = mark
            }
            print
        }
    ' main.csv > temp.csv
    mv temp.csv main.csv     

    #update the marks in individual exam files
    for file in *.csv; do
        #doing for csv files other than main.csv
        if [ "$file" != "main.csv" ]; then
            #taking basename of the file
            col=$(basename "$file" .csv)
            #if basename of the file matches exam name
            if [ "$col" == "$exam_name" ]; then
                read -p "Enter new mark for $col: " mark   #tolower introduced to make it insensitive
                awk -v roll="$roll_number" -v mark="$mark" '
                    BEGIN {
                        FS=OFS=","
                    }
                    {
                        if (tolower($1) == roll) {
                            $3 = mark
                        }
                        print $0
                    }
                ' "$file" > temp1.csv
                #move the temp.csv to the file
                mv temp1.csv "$file"
            fi
        fi
    done
}

# Function to update a student's marks of all exams  #ho gya********************************************************************
update_all_marks() {
    #read roll number
    read -p "Enter student's roll number: " roll_number
    #read name
    read -p "Enter student's name: " name

    echo "Enter the marks of the exam serially seperated by comma: "
    for file in *.csv; do
        exam=$(basename "$file" .csv)
        echo "$exam"
    done

    #updating the main.csv 
    #taking marks as comma seperated,then fill it in an array,then update the marks ie. from 3rd column 
    awk -v roll="$roll_number" -v name="$name" 'BEGIN{FS=OFS=","}{if (tolower($1) == roll) {$2 = name; getline marks < "/dev/tty"; split(marks, marks_array, ","); for (i = 3; i <= NF; i++) $i = marks_array[i-2]} print}' main.csv > temp.csv
    mv temp.csv main.csv

    #updating the individual csv files
    for file in *.csv; do
        if [ "$file" != "main.csv" ];then
        col=$(basename "$file" .csv)
        #col_number is the column number with base name as file in main.csv
        col_number=$(awk -v c="$col" 'BEGIN {FS=OFS=",";col_number=1} {if (NR==1) {for (i=1;i<=NF;i++) {if($i==c) {col_number=i}}}} END {print col_number}' main.csv)  
        #getting marks of that column number of that roll number
        marks=$(awk -v roll="$roll_number" -v da="$col_number" 'BEGIN{FS=OFS=","} tolower($1) == roll {print $da}' main.csv)
        #update the marks in that particular file
        awk -v roll="$roll_number" -v marks="$marks" 'BEGIN{FS=",";OFS=","}{if(tolower($1)==roll){$3=marks;}print $0;}' "$file" > temp.csv
        #redirecting the contents of temp.csv to that file
        cat temp.csv > "$file"
        #removing the temp file
        rm temp.csv
        fi
    done
}


# Function to list all the exam held till now    #ho gya*****************************************
list_exams() {
    csv_files=(*.csv)      #collecting list of all the csv files in the working directory in an array

    pop="main.csv"         #pop main.csv from the array csv_files as it is not desired

    index=-1              #initialising index to pop
    for i in "${!csv_files[@]}"; do           #iterate over csv_files indeces
        if [ "${csv_files[$i]}" == "$pop" ]; then      #break the loop when index equals index of main.csv in csv_files
            index=$i
            break
        fi
    done

    #check if the element was found
    if [ "$index" -eq -1 ]; then
        echo "Element '$pop' not found in the array."
    else
        #pop the element at the found index
        popped_element="${csv_files[$index_to_pop]}"
        csv_files=("${csv_files[@]:0:$index}" "${csv_files[@]:$(($index+1))}")
    fi

    #displaying the names of the exams
    for file in ${csv_files[@]};do
        echo "$(basename "$file" .csv)"    #printing exam names
    done
    #displaying the total number of exams
    echo "Total number of exams held till now: ""${#csv_files[@]}"    

}

# Function to replace 'a' with '0' in main.csv   #Ho gya**********************************
replace_absent() {    
    sed -i 's/,a,/,0,/g' main.csv   #substitute ',a,' to ',0,'
    sed -i 's/,a/,0/g' main.csv     #substitute ',a' to ',0'
}

#function to fix the weightage of all exams   # ho gya ******************************************************
fix_weightage() {
    #get a list of all CSV files in the directory
    csv_files=(*.csv )

    #pop The main.csv from array csv_files
    #specify the element to pop
    pop="main.csv"

    #find the index of the element to pop
    index_to_pop=0
    for i in "${!csv_files[@]}"; do
        if [ "${csv_files[$i]}" == "$pop" ]; then
            index_to_pop=$i
            break
        fi
    done

    #check if the element was found
    if [ "$index_to_pop" -eq 0 ]; then
        echo "Element '$pop' not found in the array."
    else
        #pop the element at the found index
        popped_element="${csv_files[$index_to_pop]}"
        csv_files=("${csv_files[@]:0:$index_to_pop}" "${csv_files[@]:$(($index_to_pop+1))}")
    fi

    #declaring array exams
    declare -a exams

    for file in "${csv_files[@]}"; do
        exam_name=$(basename "$file" .csv)
        exams+=("$exam_name")
    done

    #take user input for weights
    read -p "Enter the weightages for ${exams[*]} (comma-separated): " weightages

    #split the weightages into an array
    IFS=',' read -ra weights_array <<< "$weightages"
    echo "${#weights_array[@]}"

    #check if the number of weightages matches the number of exams
    num_exams=${#csv_files[@]}
    if [ "${#weights_array[@]}" -ne "$num_exams" ]; then
        echo "Error: The number of weightages does not match the number of exams."
        return 1
    fi

    #store the weightages weightage.txt
    printf "%s\n" "${weights_array[@]}" > weightage.txt
    echo "Weightages stored in weightage.txt"
}

#function to grade the student in this semester
generate_relative_grades() {
    read -p "Do you want to use previous weightages? [y/n] " ans

    #if user select yes then weights will be read from weightage.txt
    if [ $ans == "y" ]; then
        input_file="weightage.txt"

        #declare an array
        weights=()

        #read each line from the input file and add it to the array
        while IFS= read -r line || [[ -n "$line" ]]; do
            weights+=("$line")
        done < "$input_file"
        echo "weights are: ${weights[@]}"

    else
        csv_files=(*csv)
        # pop main.csv from the array csv_files as it is not desired
        pop="main.csv"
        index=-1  # initialising index to pop
        for i in "${!csv_files[@]}"; do  # iterate over csv_files indeces
            if [ "${csv_files[$i]}" == "$pop" ]; then  # break the loop when index equals index of main.csv in csv_files
                index=$i
                break
            fi
        done
        # check if the element was found
        if [ "$index" -eq -1 ]; then
            echo "Element '$pop' not found in the array."
        else
            # pop the element at the found index
            popped_element="${csv_files[$index]}"
            csv_files=("${csv_files[@]:0:$index}" "${csv_files[@]:$(($index+1))}")  # setting csv_files from 0 to index-1 and then from index+1 to the last file
        fi
        # getting the length of csv_files
        l=${#csv_files[@]}

        #declaring an array
        declare -a weights

        #taking user inputs to fill the array
        for (( i=0; i<$l; i++ )); do
            read -p "Enter weight ${csv_files[$i]} : " w
            weights[$i]=$w
        done
        echo "weights are: ${weights[@]}"
    fi

    #making the header
    header=""
    read -r header < main.csv
    header="$header,grade"
    echo "$header" > main_with_grades.csv

    #declaring array to store weighted scores
    weighted_scores=()
    #this is introduced to ignore first row
    count=0
    while IFS=, OFS=, read -r roll_number name mark; do
        if [ $count != 0 ]; then
            #reading the array marks ie the columns after name
            read -ra marks <<< "$mark"     #-r used to take the raw input ie without realising any special character ; -a used for reading as array
            #marks is the array with field separater space
            marks=($(echo ${marks[@]} | sed 's/,/ /g'))
            weighted_total=0
            l=${#marks[@]}
            #l decreased to ignore the total column
            ((l=l-1))
            #iterating to calculate weigghted scores
            for ((j=0;j<$l;j++)); do
                if [ ${marks[$j]} != "a" ]; then
                    ((weighted_total=weighted_total + "${marks[$j]}" * "${weights[$j]}"))
                fi
            done
            weighted_scores+=($weighted_total)
        fi
        ((count=count+1))
    done < main.csv
    echo "weighted scores: ${weighted_scores[@]}"

    # weighted_scores=(800 500 100 150)
    sorted_scores=($(printf "%s\n" "${weighted_scores[@]}" | sort -nr))
    #take top 10,20,30,40 percent students
    num_students=${#sorted_scores[@]}
    top_10=$(((num_students * 10) / 100))
    top_20=$(((num_students * 20) / 100))
    top_30=$(((num_students * 30) / 100))
    top_40=$(((num_students * 40) / 100))

    #taking the marks at which the top-10,top-20 etc are cutting off
    a=${sorted_scores[$top_10]}  
    b=${sorted_scores[$top_20]}  
    c=${sorted_scores[$top_30]}  
    d=${sorted_scores[$top_40]}

    #printing the cut-off
    echo "a: $a"
    echo "b: $b"
    echo "c: $c"
    echo "d: $d"

    #iterating over each student for grading
    count=0
    while IFS=, OFS=, read -r roll_number name mark; do
        if [ $count != 0 ]; then
            read -ra marks <<< "$mark"
            marks=($(echo ${marks[@]} | sed 's/,/ /g'))
            weighted_total=0
            l=${#marks[@]}
            ((l=l-1))
            for ((j=0;j<$l;j++)); do
                if [ ${marks[j]} != "a" ]; then
                ((weighted_total=weighted_total + "${marks[$j]}" * "${weights[$j]}"))
                fi
            done

            if ((weighted_total >= a)); then
                grade="AA"
            elif ((weighted_total >= b)); then
                grade="AB"
            elif ((weighted_total >= c)); then
                grade="BB"
            elif ((weighted_total >= d)); then
                grade="BC"
            else
                grade="CC"
            fi

            echo "$roll_number,$name,${mark[*]},$grade" >> main_with_grades.csv
        fi
        ((count=count+1))
    done < main.csv
    #moving main_with_grades.csv to main.csv
    mv main_with_grades.csv main.csv
}


# Function to show git_diff  #ho gya****************************************************
git_diff() {
    #read the remote repo path from .git_remote file
    remote_dir="$(cat .git_remote)"

    ##checking whether .git_log exists indirectly checking whether it is the remote repo initialised
    if [ ! -f "$remote_dir/.git_log" ]; then     #-f flag to check the existence of the file
        echo "Error: Git repository not initialized. Run 'git_init' first."
        return 1
    fi

    #read first commit from function call argument
    read -p "Enter the first commit hash or prefix: " commit1
    # commit1="$1"
    #read second commit from function call argument
    # commit2="$2"
    read -p "Enter the second commit hash or prefix: " commit2

    #getting the hash value using the prefixes/messages using grep 
    commit1_hash=$(grep -E "^$commit1" "$remote_dir/.git_log" | awk '{print $1}')
    commit2_hash=$(grep -E "^$commit2" "$remote_dir/.git_log" | awk '{print $1}')

    #-z flags checks for empty string
    if [ -z "$commit1_hash" ] || [ -z "$commit2_hash" ]; then
        echo "Error: One or both commits not found."
        return 1
    fi

    #initializing variables with the paths to the commits hashes
    commit1_dir="$remote_dir/$commit1_hash"
    commit2_dir="$remote_dir/$commit2_hash"

    #-d flag check whether the given path is of a directory
    if [ ! -d "$commit1_dir" ] || [ ! -d "$commit2_dir" ]; then
        echo "Error: One or both commit directories not found."
        return 1
    fi

    echo "Differences between $commit1_hash and $commit2_hash:"

    #print differences if found else print 'No differences' ; -r for recursivwly ; -q to produce brief output, indicating only whether files differ.
    diff -rq "$commit1_dir" "$commit2_dir" | awk '/^(Only in|Files)/ {print}' || echo "No differences found."
}

#function to display statistics   #Ho gya*******************************************************
statistics() {
    #taking sum of the total column and dividing by number of students
    mean=$(awk 'BEGIN {FS=OFS=","} NR>1 {sum+=$NF} END {print sum/(NR-1)}' main.csv)
    #creating an array of total marks,then sorting, then 
    median=$(awk 'BEGIN {FS=OFS=","} {arr[NR-1]=$NF} END {asort(arr); if(length(arr)/2!=0){print arr[int((length(arr)+1)/2)]}else{print arr[int(length(arr)/2)]+arr[int(length(arr)/2)+1]}}' main.csv)
    #using formula stdev=(sum(x^2)/n)-(mean^2)
    stdev=$(awk 'BEGIN {FS=OFS=","} NR>1 {sum+=$NF; sumsq+=($NF)^2} END {mean=sum/(NR-1); print sqrt(sumsq/(NR-1) - mean^2)}' main.csv)

    #display stats
    echo "Mean: $mean" 
    echo "Median: $median"
    echo "Standard Deviation: $stdev"
    #redirecting the stats to stats.txt
    echo "Mean: $mean ; Median: $median ; Standard Deviation: $stdev" > stats.txt
    echo "You can view this in stats.txt"
}

# Function to generate visualizations   #ho gya ********************************************************************
visualize() { 

    echo "Please wait till the bar graph appears..."
    python3 bar_graph.py
    echo "Please wait till the line graph appears..."
    python3 line_graph.py

}

#menu
menu() {
    echo "Bash Grader"
    echo "================================="
    echo "1. Combine CSV files"
    echo "2. Upload a new CSV file"
    echo "3. Add total column"
    echo "4. Initialize remote repository"
    echo "5. Commit changes"
    echo "6. Checkout commit"
    echo "7. Update student marks for specific exam"
    echo "8. Update student marks for all exams"
    echo "9. List the Exams Held"
    echo "10. Replace 'a' with '0' in main.csv"
    echo "11. Fix weightage of exams"
    echo "12. Genarate Relative Grades"
    echo "13. Difference between 2 commits"
    echo "14. Do git commit to remote repo using diff and patch commands"
    echo "15. Display statistics"
    echo "16. Generate visualizations"
    echo "0. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1) combine ;;
        2) read -p "Enter file path: " file_path; upload "$file_path" ;;
        3) total ;;
        4) read -p "Enter remote repo path: " remote_dir_path; git_init "$remote_dir_path" ;;
        5) read -p "Enter commit message: " commit_message; git_commit "-m" "$commit_message" ;;
        6) read -p "Enter commit identifier (message or hash): " commit_identifier; git_checkout "$commit_identifier" ;;
        7) update ;;
        8) update_all_marks ;;
        9) list_exams ;;
        10) replace_absent ;;
        11) fix_weightage ;;
        12) generate_relative_grade ;;
        13) git_diff ;;
        14) git_commit_dp ;;
        15) statistics ;;
        16) visualize ;;
        0) exit 0 ;;
        *) echo "Invalid choice. Try again." ;;
    esac

    read -n 1 -s -r -p "Press any key to continue..."
    menu
}


#checking the arguments
if [ "$1" == "list_exams" ]; then
    list_exams
elif [ "$1" == "combine" ]; then
    combine
elif [ "$1" == "upload" ]; then
    upload "$2"
elif [ "$1" == "total" ]; then
    last_column=$(awk 'BEGIN{FS=OFS=","}{if(NR==1){print $NF}}' main.csv)
    # echo $last_column
    if [ $last_column != "total" ];then
        total
    else
        cat main.csv > temp1.csv
        awk 'BEGIN{OFS=FS=","}{NF--; print}' "temp1.csv" > "main.csv"
        rm temp1.csv
        total
    fi
elif [ "$1" == "fix_weightage" ]; then
    fix_weightage
elif [ "$1" == "generate_grade" ]; then
    generate_grade
elif [ "$1" == "git_init" ]; then
    git_init "$2"
elif [ "$1" == "git_commit" ]; then
    read -p "Enter commit message: " commit_message; 
    git_commit "-m" "$commit_message"
elif [ "$1" == "git_checkout" ]; then
    git_checkout
elif [ "$1" == "git_diff" ]; then
    git_diff
elif [ "$1" == "update_all_marks" ]; then
    update_all_marks
elif [ "$1" == "update" ]; then
    update
elif [ "$1" == "statistics" ]; then
    statistics
elif [ "$1" == "visualize" ]; then
    visualize
elif [ "$1" == "replace_absent" ]; then
    replace_absent
elif [ "$1" == "menu" ]; then
    menu
elif [ "$1" == "git_commit_dp" ]; then
    read -p "Enter commit message: " commit_message; 
    git_commit_dp "-m" "$commit_message"
elif [ $1 == "generate_relative_grades" ]; then
    last_column=$(awk 'BEGIN{FS=OFS=","}{if(NR==1){print $NF}}' main.csv)
    # echo $last_column
    if [ $last_column != "grade" ];then
        generate_relative_grades
    else
        cat main.csv > temp.csv
        awk 'BEGIN{OFS=FS=","}{NF--; print}' "temp.csv" > "main.csv"
        rm temp.csv
        generate_relative_grades
    fi

fi
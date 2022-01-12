replaceString(){
	file=$1;
	matchedFileStr=$2;
	search_str=$(cat "$file" | grep tag_tf | cut -d'=' -f2 | sed -e "s/\"//g" | awk '$1=$1');
	if [ "$search_str" != "" ]; then
		line_no_tagtf=$(cat "$file" | grep tag_tf --line-number | cut -f1 -d:);
		sed -i "$line_no_tagtf s/$search_str/$matchedFileStr/" $file;
		echo "Replaced : $(eval readlink -f $file)";
	else
		line_no_tagcc=$(cat "$file" | grep tag_cost_center --line-number | cut -f1 -d:);
		new_value='tag_tf = "'$matchedFileStr'"';
		sed -i "$line_no_tagcc a $new_value" $file;
		echo "Created tag tf : $(eval readlink -f $file)"
	fi
}

env_list="dev prod staging";
file_prefix="rds ec2";
prefix_string="";
inputFile1="input.csv";
inputFile2="input2.csv";

if [ ! -f "$inputFile1" ] || [ ! -f "$inputFile2" ]; then
	echo "Input files does not exists";
	exit;
fi
#check input files exist / not
for prefix in $file_prefix
do
	prefix_string+="^${prefix}\|"
done
prefix_string=${prefix_string: : -2};
# prefix string could be ^rds\|^ec2\| - so trim last 2 char

declare -A file_Arr;
while IFS=',' read -r col1 col2
do
	if [ ! -z "$col1" ] && [ ! -z "$col2" ]; then
		file_Arr[$col1]=$col2;	
	fi;
done < $inputFile1;
#read file 1 and store it in file_Arr as assoicate array
declare -A file_Arr2;
while IFS=',' read -r col1 col2
do
	if [ ! -z "$col1" ] && [ ! -z "$col2" ]; then
		file_Arr2[$col1]=$col2;	
	fi;
done < $inputFile2;
#read file 2 and store it in file_Arr as assoicate array

for env in $env_list
do
	if [[ ! -d $env ]]; then
		continue;
		#if env not found jump next one
	fi;
	cd $env
	for dir_list in *
	do
		if [[ ! -d $dir_list ]]; then
			continue;
			#if dir not found jump next one
		fi;
		cd $dir_list;
		matched_files=$(ls | grep "$prefix_string");
		#find for files matched with generated prefix string
		for file in $matched_files
		do
			tag_cost_center=$(cat "$file" | grep tag_cost_center | cut -d'=' -f2 | sed -e "s/\"//g" | awk '$1=$1');
			tag_component=$(cat "$file" | grep tag_component_name | cut -d'=' -f2 | sed -e "s/\"//g" | awk '$1=$1');
			len_tag_cost_center=$(cat "$file" | grep tag_cost_center | wc -l);
			len_tag_component=$(cat "$file" | grep tag_component | wc -l);
			
			if ((("$len_tag_cost_center" > 1)) || (("$len_tag_component" > 1 ))); then
				echo "Multiple block : $(eval readlink -f $file)"
				continue;
			fi;
			
			if (( [ ! -z "$tag_cost_center" ] && [[ ! ${file_Arr[$tag_cost_center]} ]] ) || ( [ ! -z "$tag_component" ] && [[ ! ${file_Arr2[$tag_component]} ]] )); then
				continue;
				echo "tag cc / comp not found"
				#check for key and value exist in both files
			fi
			
			tag_cost_center_line=$(cat "$file" | grep tag_cost_center --line-number | cut -f2 -d: | awk '$1=$1');
			tag_component_line=$(cat "$file" | grep tag_component_name --line-number | cut -f2 -d: | awk '$1=$1');
			is_cc_hash=${tag_cost_center_line:0:1};
			is_comp_hash=${tag_component_line:0:1};
			
			if ([ "$is_cc_hash" == "#" ] || [ "$is_comp_hash" == "#" ]); then
				echo "Skipped : $(eval readlink -f $file)"
				continue;
			fi

			
			if ([ -z "$tag_cost_center" ] && [ ! -z "$tag_component" ]); then
				if ( [[ ${file_Arr2[$tag_component]} ]]); then
					matchedStr2="${file_Arr2[$tag_component]}";
					matchedFileStr2=`echo $matchedStr2 | sed 's/\\r//g'`;
					replaceString $file $matchedFileStr2;
				else
					# skip of record not in file 
					continue;
				fi
			elif ([ ! -z "$tag_cost_center" ] && [ -z "$tag_component" ]); then
				if ( [[ ${file_Arr[$tag_cost_center]} ]]); then
					matchedStr="${file_Arr[$tag_cost_center]}";
					matchedFileStr=`echo $matchedStr | sed 's/\\r//g'`;
					replaceString $file $matchedFileStr;
				else
					# skip of record not in file 
					continue;
				fi
			elif ([ ! -z "$tag_cost_center" ] && [[ ${file_Arr[$tag_cost_center]} ]] && [ ! -z "$tag_component" ] && [[ ${file_Arr2[$tag_component]} ]]); then
				matchedStr="${file_Arr[$tag_cost_center]}";
				matchedStr2="${file_Arr2[$tag_component]}";
				#get value of string from input fileS
				matchedFileStr=`echo $matchedStr | sed 's/\\r//g'`;
				matchedFileStr2=`echo $matchedStr2 | sed 's/\\r//g'`;
				#remove default carriage return from mateched string
				if ([ "$matchedFileStr" != "" ] && [ "$matchedFileStr" == "$matchedFileStr2" ]); then
					replaceString $file $matchedFileStr;
				else
					echo "Field mismatch : $(eval readlink -f $file)"
				fi
			else
				continue;
				# go next
			fi
		done
		cd ..
	done
	cd ..
done
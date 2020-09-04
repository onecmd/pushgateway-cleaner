#!/bin/bash
# Cronjob task to cleanup pushgateway metrics
#
# Set env:
#  export PUSHGATEWAY_HOST="pushgateway.onecmd.com"
#  export TARGET_JOBS="[{'name':'kubernetes-resource-check','duration':1200,'group_labels':'container,pod'}
#                      ,{'name':'gitlab_statistics','duration':600,'group_labels':''}]"
#
### Add to crontab
##  crontab -e
# */2 * * * * /opt/pushgateway-cleaner/cleanup_pushgateway_metrics.sh >> /var/log/cleanup_pushgateway_metrics.log 2>&1
#

###########################
# variables

echo "PUSHGATEWAY_HOST=${PUSHGATEWAY_HOST}"
pushgateway_url="http://${PUSHGATEWAY_HOST}"

echo "TARGET_JOBS=${TARGET_JOBS}"
TARGET_JOBS=`echo "$TARGET_JOBS" | sed "s/'/\"/g"`

metrics_tmp_file="/tmp/pushgateway_metrics.txt"

###########################
# functions

function get_all_metrics(){
	curl  -sL --proxy "" ${pushgateway_url}/metrics | grep "^push_time_seconds" | grep -v "^#" > ${metrics_tmp_file}
}

function cleanup_one_job(){
	job_name=$1
	duration=`echo "$2" | awk '{print int($0)}'`
	group_labels=$3

	IFS_old=$IFS

	IFS=$'\n'
	job_metrics_lines=`cat ${metrics_tmp_file} | grep job=\"${job_name}\"`

	for metrics_line in ${job_metrics_lines}
	do
		# Get metrics last column update time:
        ftime=`echo ${metrics_line} | awk -F " " '{print $NF}'`
        metrics_time=$(printf "%0.f" $ftime)
        metrics_time_str=`date -d @"$metrics_time" +"%Y-%m-%d_%H:%M:%S"`

        # Check metrics if expired:
        cur_time=`date +%s`
        past=$((cur_time-metrics_time))
        if [ $past -lt $duration ]; then
        	# metrics not expired, keep it:
            echo "Not expired: ${metrics_line} ${metrics_time_str}"
            continue
        else
        	# Metrics expired, start to clean it:

        	# Erase last colmn time string
	        metrics=`echo ${metrics_line} | awk '{$NF="";print}'`
        	# convert to json format, so that can get labels well:
	        metrics_json=`echo $metrics | sed 's/push_time_seconds{/{\"/g' | sed 's/,/,\"/g' | sed 's/=/\":/g'`
	       	#echo "Metrics json: $metrics_json"

	       	# Generate the metrics URL:
	        path="${pushgateway_url}/metrics/job/$job_name"

	        # Add labels to metrics URL:
	        if [ -n "${group_labels}" ]; then
	        	# Split labels string to array:
		        IFS=$','
		        labels=(${group_labels})

		        IFS=$'\n'
		        for label in ${labels[@]}
		        do
		        	# Retrive label value from metrics:
		            value=`echo ${metrics_json} | jq -r ".$label"`
		            path="$path/$label/$value"
		        done
	    	fi

	        echo "DELETE path: $path ${metrics_time_str}"
	        curl -X DELETE -sL --proxy "" $path
        fi
	done

	IFS=$IFS_old
}

function main(){

	jobs=`echo "${TARGET_JOBS}" | jq "."`
	if [ $? -ne 0 ]; then
		echo "Failed to parse ENV parameter TARGET_JOBS: ${TARGET_JOBS}"
		exit 1
	fi

	length=`echo "${TARGET_JOBS}" | jq '.|length'`

	get_all_metrics
	if [ $? -ne 0 ]; then
		echo "Failed to get metrics by url: ${pushgateway_url}/metrics"
		exit 1
	fi

	for index in `seq 0 $length`
	do
		job_name=`echo ${jobs} | jq -r ".[$index].name"`
		job_duration=`echo ${jobs} | jq -r ".[$index].duration"`
		job_labels=`echo ${jobs} | jq -r ".[$index].group_labels"`

		if [ -n "${job_name}" ] && [ ! "X${job_name}" == "Xnull" ]; then
			echo "------ Clean for job: ${job_name} ${job_duration} ${job_labels} ------"
			cleanup_one_job ${job_name} ${job_duration} ${job_labels}
		fi
	done
}

########################
# Main

main

# pushgateway-cleaner
A tool for prometheus-pushgateway to clean the metrics. Pushgateway will not clean the metrics by default, and also not provide such function, we had to manage the metrics in Pushgateway by ourself, this is a such tool to help us.

## Usage

### Precondition
[jq](https://stedolan.github.io/jq/download/) should be installed.

### Set env
```
export PUSHGATEWAY_HOST="pushgateway.onecmd.com"
export TARGET_JOBS="[{'name':'kubernetes-resource-check','duration':1200,'group_labels':'container,pod'}
                    ,{'name':'gitlab_statistics','duration':600,'group_labels':''}]"
```
- NOTE: Add it to the script directly if not want to export in system ENV.

TARGET_JOBS json items:

| Attribute  | Type | Comment |
| ------------- | ------------- | ------------- |
| name  | String  | Metrics name |
| duration  | Integer  | Seconds, expired time for Metrics, the metrics age more than this value will be deleted |
| group_labels  | String  | Metrics group labels |

- How to get the group_labels:
1. Get the response: http://${PUSHGATEWAY_HOST}/metrics;
2. Find the line include the job name which need to cleanup;

   eg. 'job="kubernetes-resource-check"':
   ```
   metrics_name{job="kubernetes-resource-check", container="test_container", pod="test_pod"} 1.5992256155004728e+09
   ```
3. Then 'container' and 'pod' are the labels, then the group_labels value should be: 'container,pod';

### Add to crontab
```
#crontab -e
*/2 * * * * /opt/pushgateway-cleaner/cleanup_pushgateway_metrics.sh >> /var/log/cleanup_pushgateway_metrics.log 2>&1
```
Also can add to Kubernetes cronjob if use Kubernetes.


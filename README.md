# pushgateway-cleaner
A tool for prometheus-pushgateway to clean the metrics. Pushgateway will not clean the metrics, we had to manage the metrics in Pushgateway, this is a such tool.

## Usage

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
| duration  | Integer  | Expired time for Metrics, the metrics age more than this value will be deleted |
| group_labels  | String  | Metrics group labels |


### Add to crontab
```
#crontab -e
*/2 * * * * /opt/pushgateway-cleaner/cleanup_pushgateway_metrics.sh >> /var/log/cleanup_pushgateway_metrics.log 2>&1
```
Also can add to Kubernetes cronjob if use Kubernetes.


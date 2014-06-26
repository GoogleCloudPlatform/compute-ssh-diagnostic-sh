### This is a troubleshooting script for Compute Engine customer issues

Self diagnosis tool to identify issues with SSH login/accessibility of your linux based Google Compute Engine instance.
Gather relevant diagnostic information in a single exchange for the support team. The tool does not aim to fix any issues just log information for analysis.

### Usage:
```
gcutil addinstance [instance_name] --metadata=startup-script-url:http://storage.googleapis.com/gce-scripts/gee.sh
```
You can inspect the output with
```
gcutil getserialportoutput [instance_name]
```
once the instance is up.

you may use deploy.sh to deploy a modified version of this script to your own GCS bucket
redefining the ACCOUNT PROJECT BUCKET variables in the script and calling your addinstance
with http://storage.googleapis.com/[YOUR_BUCKET]/gee.sh defined as startup script.

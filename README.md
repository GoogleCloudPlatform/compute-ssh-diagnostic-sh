### This is a troubleshooting script for Compute Engine customer issues

Self diagnosis tool to identify issues with SSH login/accessibility of your linux based Google Compute Engine instance. Gather relevant diagnostic information in a single exchange for the support team. The tool does not aim to fix any issues, just log information for analysis.

### Usage

Note: ideally you should provide --zone [zone of the instance] to avoid zone lookups
or specify gcloud config set compute/zone [zone_name]

#### for an existing instance
```
gcloud compute instances add-metadata [instance_name] --metadata startup-script-url=http://storage.googleapis.com/gce-scripts/gee.sh
```
WARNING: the following command will reboot the machine
if uptime is a concern you should snapshot and clone your
disk and instance with the startup-script specified instead
:

```
gcloud compute instances reset [instance_name]
```

if this fails with resource not ready you need to delete the instance keeping the disk take note of the instance configuration than recreate the instance with

```
gcloud compute instances describe [instance_name]
gcloud compute instances delete [instance_name] --keep-disks all
gcloud compute instances create [instance_name] --disk boot=yes name=[instance_disk_name] --metadata startup-script-url=http://storage.googleapis.com/gce-scripts/gee.sh
```

#### for a new instance
```
gcloud compute instances create [instance_name] --metadata startup-script-url=http://storage.googleapis.com/gce-scripts/gee.sh
```

#### You can inspect the output with
```
gcloud compute instances get-serial-port-output [instance_name]
```
once the instance is up.

you may use deploy.sh to deploy a modified version of this script to your own GCS bucket redefining the ACCOUNT PROJECT BUCKET variables in the script and calling your addinstance with http://storage.googleapis.com/[YOUR_BUCKET]/gee.sh defined as startup script.

### Privacy

The customer has privacy control with flags which skips the given section
```
[..] gee.sh --skip=[network,metadata,authkeys,sshdconf,sshd,sys,usersec,traceroute]
```
Read the comments in the code to learn the reason for each command and how to interpret the output.  Alternatively if network connection to cloud storage is still working the output can be directed to a file and that copied across after running the tool, which file than can be trimmed by the customer before sending it to the support team.

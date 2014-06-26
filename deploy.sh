#!/bin/sh
# Copyright 2014 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ACCOUNT=$USER@google.com
PROJECT=70795436982
BUCKET=gce-scripts
gcloud config set account $ACCOUNT
gcloud config set project $PROJECT
gsutil cp gee.sh gs://$BUCKET/gee.sh
# TODO(sub) auto-generate sample log and provide a flag to do skip it
#gsutil cp gee_sample_log.txt gs://$BUCKET/gee_sample_log.txt
gsutil setmeta  -h "Cache-Control:public, max-age=0, no-transform" gs://$BUCKET/gee.sh # gs://$BUCKET/gee_sample_log.txt
gsutil acl set public-read gs://$BUCKET/gee.sh # gs://$BUCKET/gee_sample_log.txt

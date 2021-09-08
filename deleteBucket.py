#!/usr/bin/env python

import boto3
import sys



print(sys.argv[1]) 

BUCKET = sys.argv[1]


s3 = boto3.resource('s3')
bucket = s3.Bucket(BUCKET)
bucket.object_versions.delete()

# if you want to delete the now-empty bucket as well, uncomment this line:
bucket.delete()


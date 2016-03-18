#!/bin/bash
set -x 

METEOR_APP_URL=summit2015.reversim.com
COLLECTIONS="users agenda proposals sponsors wishes"
DUMP_LOCATION=./dbbackup

# 1. Ensure user has meteor & mongo installed and available in path
if [ ! $(which meteor) ] ; then
  echo "Meteor is not installed on this computer (or at least it's not in the PATH)"
  echo "install Meteor by running"
  echo "> curl https://install.meteor.com | /bin/sh"
  exit 1
fi

if [ ! $(which mongodump) ] ; then
  echo "Need to install mongo separately from Meteor first (meteor only installs"
  echo "the bare minimum mongo, and doesn't include the utilities we need)"
  echo ""
  echo "1. Try 'brew install mongodb'"
  echo ""
  echo "2. If that doesn't work, follow the manual steps at"
  echo "http://docs.mongodb.org/v2.4/installation/"
# TODO: offer user to install mongo manually on their behalf, though this
# is a little ambitious, especially beyond OSX.
  exit 1
fi

echo "-----------------------------------------------------------"
echo "Starting to download from server"
echo "(if your deployment has a password, it will be needed here)"
echo "-----------------------------------------------------------"

TEMPFILE=URL.tmp
# HACK: we have to let meteor mongo have stdout to prompt for password so we
# can't use $(...) and instead tee and tail the result
meteor mongo --url $METEOR_APP_URL | tee $TEMPFILE

if [ $PIPESTATUS -ne 0 ] ; then
  echo "Could not connect to your app's server."
  echo $USAGE
  exit 1
fi

MONGO_SERVER_URL=$(tail -n 1 $TEMPFILE)
rm $TEMPFILE

# regex works (tested) for what meteor.com returns for 0.7.0
# sample server url:mongodb://client:THIS-IS-PASSWORD@MONGO-SERVER-URL/DATABASE-URL
# for python version of similar tool: http://pydanny.com/parsing-mongodb-uri.html
MONGODUMP_ARGUMENTS=$(echo $MONGO_SERVER_URL | sed "s|mongodb://\([a-zA-Z0-9-]*\):\([a-zA-Z0-9-]*\)@\([a-zA-Z0-9\:.-]*\)/\(.*\)|--username \1 --password \2 --host \3 --db \4|")

if [ $? -ne 0 ] ; then
  echo "Failed to parse mongodump results, please take a look at this script (it may be outdated)"
  exit 1
fi

rm -r $DUMP_LOCATION
mongodump $MONGODUMP_ARGUMENTS --out $DUMP_LOCATION

for c in $COLLECTIONS
do
    mongoexport $MONGODUMP_ARGUMENTS --out $DUMP_LOCATION/$c.json -c $c
done

if [ $? -ne 0 ] ; then
  echo "Mongodump Failed!"
  echo $USAGE
  exit 1
fi

echo "-----------------------------------------------------------"
echo "All done, enjoy!"
echo "-----------------------------------------------------------"
cd $ORIGINAL_DIR

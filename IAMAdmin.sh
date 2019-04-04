#!/bin/bash

# v1.0  2018/12/18 Tara Ram
# v1.1  2019/02/12 Jon Treharne - Add Email Tag for Creation as mandatory
#
#       -U <IAM User>           - Mandatory
#       -G <IAM Group ID>       - optional
#       -E <Corp Email Address> - Mandatory for Creation
#       -a | -d | -v            - Activity, Add, Delete or View - MUST specify only one activity
# INFO:
# An IAM role is associated with the instance this code is running on.
# The role has policies: IAMFullAccess & SecretsManagerReadWrite (to allow the creation of a password)

## Functions
CheckOptions() {
   while getopts advU:G:E: OPTION 2>&-
   do case "$OPTION" in
        a) AddActivity=1 ;;
        d) DeleteActivity=1 ;;
        v) ViewActivity=1 ;;
        U) IAMUserID=${OPTARG} ;;
        G) IAMGroupID=${OPTARG} ;;
        E) UserEmail=${OPTARG} ;;
        *) Usage ;;
     esac
   done
}

Usage() {
 echo -e "\n
  Usage: ${0##*/} (-a | -d | -v) -U <IAMUserID> [-G <IAMGroupID>] [-E <UserEmail>]

        -a, -d & -v are activities - Add, Delete or View.
        -U Specify an existing or to be created IAM User ID (depending on the activity)
        -G Mandatory for User Creation, specify the Group the user should belong to.
        -E Mandatory for User Creation, specify the user's corporate Email Address.
 " >&2
 exit
}

# Option
Log() {
 echo -ne "$(date +%Y%m%d%H%M%S) $*\n"
}

# MAIN
declare -i AddActivity=0 DeleteActivity=0 ViewActivity=0
IAMUserID=""
DefaultIAMGroupID="None"

# Validate options
CheckOptions $*



# User ID MUST be specified
  if [ -z "${IAMUserID}" ]
  then
    Log "ERROR: MUST specify an IAM User ID with -U option - Exiting"
    Usage
  fi

# Check that only one option has been specified
  if [ ${OptsTotal:=$((AddActivity+DeleteActivity+ViewActivity))} -eq 0 -o ${OptsTotal} -gt 1 ]
  then
    Log "ERROR: Must specify a single activity: -a (Add), -d (Delete) or -v (View) - Exiting"
    Usage
  fi

# Save chosen activity (maybe use this later)
((AddActivity))         && ChosenActivity="Add"
((DeleteActivity))      && ChosenActivity="Delete"
((ViewActivity))        && ChosenActivity="View"

if ((AddActivity))
  then
  if [ -z "${IAMGroupID}" ]
  then
  Log "ERROR: While adding a User, you MUST specify an User Group with -G option - Exiting"
    Usage
  fi
 fi

# Default the Group ID if not specified
IAMGroupID="${IAMGroupID:=${DefaultIAMGroupID}}"

aws configure set default.region eu-west-2

Log "Info: Performing: ${ChosenActivity} activity for User: ${IAMUserID} and Group: ${IAMGroupID}"

Log "Info: Getting list of existing IAM users..."
AWSIAMCMD=" $(aws iam list-users --output text 2>&1 | awk '{printf $NF" "}') "
AWSCMDRC=$?
  if [ ${AWSCMDRC} -ne 0 ]
  then
    Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to list-users - Exiting"
  fi
AllIAMUsers="${AWSIAMCMD}"
  [ "${AllIAMUsers}" = "${AllIAMUsers#* ${IAMUserID} }" ] ; ExistingUser=$?

# Add a new user
  if ((AddActivity))
  then
      if ((ExistingUser))
      then
        Log "Warning: Add activity selected but user: ${IAMUserID} already exists - Switching to View mode:"
        exec $0 -v -U ${IAMUserID} -G ${IAMGroupID}
  fi
    # User ID MUST be specified
    if [ -z "${UserEmail}" ]
    then
    Log "ERROR: For User creation, you MUST specify a Corporate Email Address with -E option - Exiting"
    Usage
    fi

    Log "Info: First generating a random password..."
    set -- "$(aws secretsmanager get-random-password --region eu-west-1 --password-length 20 --require-each-included-type --output text)"
      if [ $? -ne 0 ]
      then
        Log "ERROR: When generating a random password - Exiting."
        exit 1
      fi
    RandomPassword="$1"

# Now issue the command to create the user
    AWSCMD="$(aws iam create-user --user-name "${IAMUserID}" --tags Key=Email,Value="${UserEmail}" 2>&1)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
        Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to create-user - Exiting"
        exit 1
      fi
#    Log "Info: Output from Add activity: ${AWSCMD}"
    Log "Info: Output from Add activity:"
      while read AddActivityInfo
      do
        Log "Info: ${AddActivityInfo}"
      done <<<"${AWSCMD}"

# Now set the password.
    Log "Info: Setting password..."
    AWSCMD="$(aws iam create-login-profile --user-name "${IAMUserID}" --password "${RandomPassword}" --password-reset-required 2>&1)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
        Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to set password - Exiting"
        exit 1
      fi

# Now add user to group
    Log "Info: Now adding the user: ${IAMUserID} to group: ${IAMGroupID}"
    AWSCMD="$(aws iam add-user-to-group --user-name "${IAMUserID}" --group-name "${IAMGroupID}" 2>&1)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
        Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to add-user-to-group - Exiting"
        exit 1
      fi
    Log "SUCCESS: User: ${IAMUserID} with group: ${IAMGroupID} has been created with password: ${RandomPassword}\n"
  fi

# Delete an existing user
  if ((DeleteActivity))
  then
      if ((!ExistingUser))
      then
        Log "Error: Trying to delete user: ${IAMUserID} but does not exist - Exiting"
        exit 1
      fi
# Remove user from group first - see if it's in the group
    Log "Info: Now removing the user: ${IAMUserID} from group: ${IAMGroupID}"
    AWSCMD="$(aws iam remove-user-from-group --user-name "${IAMUserID}" --group-name "${IAMGroupID}" 2>&1)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
          if [ "${AWSCMD}" = "${AWSCMD#*"An error occurred (NoSuchEntity) when calling the RemoveUserFromGroup operation:"}" ]
          then
            Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to remove-user-from-group - Exiting"
            exit 1
          else
            Log "Warning: User: ${IAMUserID} does not belong to group: ${IAMGroupID} - continuing..."
          fi
      fi
#    Log "Output from remove-user-from-group activity: ${AWSCMD}"

# Delete login profile
    Log "Info: Removing the login profile..."
    AWSCMD="$(aws iam delete-login-profile --user-name "${IAMUserID}" 2>&1)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
        Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to delete login profile - Exiting"
        exit 1
      fi

# Now perform the actual delete operation
    Log "Info: Deleting the actual user..."
    AWSCMD="$(aws iam delete-user --user-name "${IAMUserID}" 2>&1)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
        Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to delete-user - Exiting"
        exit 1
      fi
    Log "SUCCESS: User: ${IAMUserID} was deleted."
  fi

# Viewing an existing user
  if ((ViewActivity))
  then
      if ((!ExistingUser))
      then
        Log "ERROR: User: ${IAMUserID} does not exist, nothing to show - Exiting"
        exit 1
      fi
    Log "Info: Showing information for user: ${IAMUserID}:"
    AWSCMD="$(aws iam list-groups-for-user --user-name ${IAMUserID} --output text)"
    AWSCMDRC=$?
      if [ ${AWSCMDRC} -ne 0 ]
      then
        Log "ERROR: Received exit code: ${AWSCMDRC} and output \"${AWSCMD}\" when trying to list-groups-for-user - Exiting"
        exit 1
      fi
      while read AWSDCMDLineInfo
      do
        Log "Info: ${AWSDCMDLineInfo}"
      done <<<"${AWSCMD}"
  fi

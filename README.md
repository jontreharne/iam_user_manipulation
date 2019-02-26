# iam_user_manipulation
CAAF (Container-as-a-Function) to add, delete and view IAM users.

This image allows you to interact with your AWS account using your programmatic keys by running a bash script within the container,
providing a quick way to manage users without installing or having knowledge of AWS cli.

# Pre-Requisites
Docker installed on host machine.

# How do I do this?

Setup an Alias in your bash/shell profile:

```vi ~/.bash_profile```

insert the following:

```alias iam_manage="docker run -it -v ~/.aws/credentials:/root/.aws/credentials jon2thet/iamuseradmin:latest"```

You will now need to source your ~/.bash_profile by running:

```source ~/.bash_profile```

Get a terminal session in a directory above your python code. execute the following command:

```iam_manage```

This will now run the iam bash script.

# Arguments available

-a | -d | -v            - Activity, Add, Delete or View - MUST specify only one activity.

-U <IAM User>           - Mandatory.
  
-G <IAM Group ID>       - Optional for creation, mandatory if for deletion if a user is assigned to a group.
  
-E <Corp Email Address> - Mandatory for Creation.

# Also available

At Docker Hub https://hub.docker.com/r/jon2thet/iam_user_manipulation

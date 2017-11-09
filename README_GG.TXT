# This tutorial is aimed at setting up a container running AWS
# Greengrass and connecting it to a specific Amazon AWS isntance.


# NOTE: You need to have an AWS Greengrass account fully setup and in
#       good standing with all the license terms accepted in order to
#       make use of this exmaple.


# You will select one of the following use cases
#
# Section 1) Use a pre-built container and configure it to connect
# Section 2) Build your own container that is custom and configured to connect
# Section 3) Rebuilding the reference container

#==================================================================
#   Section 1 - Use a pre-built container and configure it to connect
#==================================================================

# Login into dom0
cube-console dom0

# Download the prebuilt and signed container
wget https://github.com/WindRiver-OpenSourceLabs/cube-gg-prebuilt/raw/master/cube-gg.tar.bz2

# Load the container on the system
cube-ctl add cube-gg.tar.bz2

# Start the container
cube-ctl start cube-gg

# Access the container for initial one time configuration
cube-console cube-gg

# Install your AWS Greengrass keys via SCP or ssh
# ... Some command to get your two key files *.crt and *.key
# The keys go in /greengrass/certs
# You could also copy them directly other ways by using the 
# rootfs mounts available from dom0.

(cd /greengrass/certs;\
wget http://SOME_HOST/demo/5d3659c7ee-certificate.pem.crt ; \
wget http://SOME_HOST/demo/5d3659c7ee-private.pem.key ;\
)

# Now you need to know your ARN string, the IOTHOST string and your
# REGION from the AWS Console.  Below is an example.  You must change
# these values for your specific instance.  If you omit the variables
# and just run update_config, it will ask you for each of the inputs
# it needs.

ARN=arn:aws:iot:us-east-1:111111111567:thing/GW-Demo_Core \
REGION=us-east-1 \
IOTHOST=azzzzzzzlj8y9n \
bash ./update_config

# Now go and use your instance in the AWS Console




#==================================================================
#   Section 2 - Build your own container that is custom and configured to connect
#==================================================================

# Using these instructions you can create a container which is already
# populated with the keys and config.json to connect immediately.
#
# If you are using IMA, the private signing key needs to be available
# in the directory you are building the container and should be called
# "ima_privkey.pem" so that the AWS Greengrass binaries will be
# allowed to execute in the container.

wget https://raw.githubusercontent.com/WindRiver-OpenSourceLabs/cube-hello/master/mk-cube-gg.sh

# Now you must scp or wget your copy of the AWS Greengrass to the
# current directory:

wget https://myserver/mydir/greengrass-linux-x86-64-1.1.0.tar.gz

# Obtain the Verisign Root CA

curl -O http://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem

# You must place your AWS Greengrass keys in this directory as well
# with scp or wget.  You need the keys that look like XXXXXXXXX-keyname example:
#         5d3659c7ee-certificate.pem.crt
#         5d3659c7ee-private.pem.key
scp some_host:/keys_dir/* . 

# Install needed programs which are not installed by default
smart update
smart install -y libsqlite3-0 sqlite3 python-argparse python-json python-numbers

# Use your ARN, IOTHOST and REGION found in your AWS Console to construct
# the container image
ARN=arn:aws:iot:us-east-1:111111111567:thing/GW-Demo_Core \
REGION=us-east-1 \
IOTHOST=azzzzzzzlj8y9n \
bash ./mk-cube-gg.sh

# You are done and can deploy the image to your device


#==================================================================
#   Section 3 - Rebuilding the reference container
#==================================================================
#
# For this type of container it will not be able to run without
# making changes to the config.json.
#
# If you are using IMA, the private signing key needs to be available
# in the directory you are building the container and should be called
# "ima_privkey.pem" so that the AWS Greengrass binaries will be
# allowed to execute in the container.

wget https://raw.githubusercontent.com/WindRiver-OpenSourceLabs/cube-hello/master/mk-cube-gg.sh

# Now you must scp or wget your copy of the AWS Greengrass to the
# current directory:

wget https://myserver/mydir/greengrass-linux-x86-64-1.1.0.tar.gz

# Obtain the Verisign Root CA

curl -O http://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem

# Install needed programs which are not installed by default
smart update
smart install -y libsqlite3-0 sqlite3 python-argparse python-json python-numbers

# Create the container's tar.bz2
PRIVKEY="" CERTKEY="" bash ./mk-cube-gg.sh


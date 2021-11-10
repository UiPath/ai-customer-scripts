## Pre-requisites:
aws and jq dependencies needs to be downloaded in the machine where script is getting executed.

sudo apt install -y jq awscli

## Usage: 

```
sudo su 

cd ~

mkdir migration

cd migration

git clone https://github.com/UiPath/ai-customer-scripts

cd ai-customer-scripts

git checkout singledatasetdownload

cd platform/datasetdownload

```

Generate the creds.json (storage credential file) file by running the script

./get-credentials.sh

Note: If running from a third machine make sure to run the following command :

./get-credentials.sh {PUBLIC_IP_OF_MACHINE}

Above script will generate creds.json file. Replace the content in creds.json file

Replace the content in the input.json file , these values can be found from the browser network call in ai-app.

Create a directory by name {DATASET_NAME}

Then execute the below command to copy the dataset to the {DATASET_NAME} directory
sh export.sh creds.json input.json ./{DATASET_NAME}/

In the above command , creds.json is the storage credential file,
input.json is the input file with input parameters for the script,
{DATASET_NAME} is the name of the directory where the dataset needs to be copied


Above script will generate the data in {DATASET_NAME} directory.

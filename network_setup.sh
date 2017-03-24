#!/bin/bash

function usage () {
	echo
	echo "======================================================================================================"
	echo "Usage: "
	echo "      network_setup.sh [channel-name] [total-channels] [chaincodes] [endorsers count] [tls]  <up|down|retstart>"
	echo
	echo "./network_setup.sh -n 'channel-name' -C 2 -c 3 -e 4 restart"
	echo "		-n       channel name"
	echo "		-C       # of Channels that can be created"
	echo "		-c       # of Chaincodes that can be created"
	echo "		-e       # of endorsers that can be used for tests"
	echo "		-f       provide docker compose file"
	echo "		-t       Enable TLS"
	echo "		up       Launch the network and start the test"
	echo "		down     teardown the network and the test"
	echo "		retstart Restart the network and start the test"
	echo "======================================================================================================"
	echo
}

function validateArgs () {
	if [ -z "${UP_DOWN}" ]; then
		echo "One of the option up / down / restart is missing"
		usage
		exit 1
	fi
}

function clearContainers () {
        CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
}

function networkUp () {
	echo "============= Starting the network with below configurations ================"
	printOptions
	CURRENT_DIR=$PWD
        source generateCfgTrx.sh $CH_NAME $CHANNELS
	cd $CURRENT_DIR

	CHANNEL_NAME=$CH_NAME CHANNELS_NUM=$CHANNELS CHAINCODES_NUM=$CHAINCODES ENDORSERS_NUM=$ENDORSERS docker-compose -f $COMPOSE_FILE up -d 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to pull the images "
		exit 1
	fi
	docker logs -f cli
}

function networkDown () {
        docker-compose -f $COMPOSE_FILE down
        #Cleanup the chaincode containers
	clearContainers
	#Cleanup images
	removeUnwantedImages
        #remove orderer and config txn
        rm -rf $PWD/crypto/orderer/orderer.block
        rm -rf $PWD/crypto/orderer/channel*.tx
}

##process all the options
while getopts "tC:c:e:n:f:h" opt; do
  case "${opt}" in
    n)
      CH_NAME="$OPTARG"
      ;;
    C)
      CHANNELS="$OPTARG"
      ;;
    c)
      CHAINCODES="$OPTARG"
      ;;
    e)
      ENDORSERS="$OPTARG"
      ;;
    t)
      TLS="y"
      ;;
    h)
      usage
      exit 0
      ;;
    f)
      COMPOSE_FILE="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

## this is to read the argument up/down/restart
shift $((OPTIND-1))

: ${CH_NAME:="mychannel"}
: ${CHANNELS:="1"}
: ${CHAINCODES:="1"}
: ${ENDORSERS:="4"}
: ${TLS:="N"}
: ${COMPOSE_FILE:="docker-compose.yaml"}

UP_DOWN="$@"

validateArgs


function printOptions () {
	echo "------- Channel name : $CH_NAME"
	echo "------- Total Channels : $CHANNELS"
	echo "------- Total Chaincodes : $CHAINCODES"
	echo "------- Total Endorsers : $ENDORSERS"
        echo "------- Used Docker-compose : $COMPOSE_FILE"
}
#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	echo "================== Clearing the network ================"
	printOptions
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	echo "================== RESTART ================"
	networkDown
	networkUp
else
	usage
	exit 1
fi

#!/bin/bash

CHANNEL_NAME=$1
CHANNEL_COUNT=$2

: ${CHANNEL_NAME:="mychannel"}
: ${CHANNEL_COUNT:="1"}

echo "Channel name - "$CHANNEL_NAME
echo "Totla channels - "$CHANNEL_COUNT
echo

#Backup the original configtx.yaml
cp ../../common/configtx/tool/configtx.yaml ../../common/configtx/tool/configtx.yaml.orig
cp configtx.yaml ../../common/configtx/tool/configtx.yaml

cd $PWD/../../
echo "Building configtxgen"
make configtxgen

echo "Generating genesis block"
./build/bin/configtxgen -profile TwoOrgs -outputBlock orderer.block
mv orderer.block examples/e2e/crypto/orderer/orderer.block

for (( i=0; $i<$CHANNEL_COUNT; i++))
do
	echo "Generating channel configuration transaction for channel '$CHANNEL_NAME$i'"
	./build/bin/configtxgen -profile TwoOrgs -outputCreateChannelTx channel$i.tx -channelID $CHANNEL_NAME$i
	mv channel$i.tx examples/e2e/crypto/orderer/channel$i.tx
done

#reset configtx.yaml file to its original
cp common/configtx/tool/configtx.yaml.orig common/configtx/tool/configtx.yaml
rm common/configtx/tool/configtx.yaml.orig

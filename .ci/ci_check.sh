#!/bin/bash

set -e

curl -LO https://raw.githubusercontent.com/FISCO-BCOS/FISCO-BCOS/master/tools/build_chain.sh && chmod u+x build_chain.sh
bash <(curl -s https://raw.githubusercontent.com/FISCO-BCOS/FISCO-BCOS/master/tools/ci/download_bin.sh)
echo "127.0.0.1:4 agency1 1,2,3" >ipconf
./build_chain.sh -e bin/fisco-bcos -f ipconf -p 30300,20200,8545 -v 2.1.0
./nodes/127.0.0.1/start_all.sh
./nodes/127.0.0.1/fisco-bcos -v

#config console
bash <(curl -s https://raw.githubusercontent.com/FISCO-BCOS/console/master/tools/download_console.sh)
cp -n console/conf/applicationContext-sample.xml console/conf/applicationContext.xml
cp nodes/127.0.0.1/sdk/* console/conf/

#deploy helloworld
cd console
bash start.sh <<EOF
deploy HelloWorld
EOF
hello_address=$(grep 'HelloWorld' deploylog.txt | awk '{print $5}')
cd -

curl -LO https://raw.githubusercontent.com/FISCO-BCOS/web3sdk/master/tools/get_account.sh

bash get_account.sh

cd accounts
# shellcheck disable=SC2012
# shellcheck disable=SC2035
pem_file=$(ls *.pem | awk -F'.' '{print $0}')

cd -

cp src/test/resources/wecross-sample.toml src/test/resources/wecross.toml
cp src/test/resources/stubs/bcos/stub-sample.toml src/test/resources/stubs/bcos/stub.toml

#generate wecross cert
bash ./scripts/create_cert.sh -c -d ./ca
bash ./scripts/create_cert.sh -n -D ./ca -d ./ca/node
mkdir -p ./src/test/resources/p2p
cp ./ca/ca.crt ./src/test/resources/p2p/
cp ./ca/node/node.crt ./src/test/resources/p2p/
cp ./ca/node/node.key ./src/test/resources/p2p/
cp ./ca/node/node.nodeid ./src/test/resources/p2p/

#configure wecross
if [ "$(uname)" == "Darwin" ]; then
    # Mac
    sed -i "" "s/0x8827cca7f0f38b861b62dae6d711efe92a1e3602/${hello_address}/g" src/test/resources/stubs/bcos/stub.toml
    sed -i "" "s/0xa1ca07c7ff567183c889e1ad5f4dcd37716831ca.pem/${pem_file}/g" src/test/resources/stubs/bcos/stub.toml
else
    # Other
    sed -i "s/0x8827cca7f0f38b861b62dae6d711efe92a1e3602/${hello_address}/g" src/test/resources/stubs/bcos/stub.toml
    sed -i "s/0xa1ca07c7ff567183c889e1ad5f4dcd37716831ca.pem/${pem_file}/g" src/test/resources/stubs/bcos/stub.toml
fi

cp accounts/* src/test/resources/stubs/bcos/
cp nodes/127.0.0.1/sdk/* src/test/resources/stubs/bcos/

rm -rf accounts

./gradlew verifyGoogleJavaFormat
./gradlew build -x test
./gradlew test -i
./gradlew jacocoTestReport

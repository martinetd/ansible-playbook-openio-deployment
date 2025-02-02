#! /usr/bin/env bats

# Tests
get_ID_node() {
  #for i in $(docker ps -aq); do
  #  export SUT_ID=$(docker inspect $i| grep -B400 ${SUT_IP}|grep Hostname\" | uniq| sed -e 's@.*"\(.*\)",@\1@')
  #done
  if [[ "$SUT_IP" == "172.17.0.2" ]]; then export SUT_ID=${TRINODE_ID1}; fi 
  if [[ "$SUT_IP" == "172.17.0.3" ]]; then export SUT_ID=${TRINODE_ID2}; fi 
  if [[ "$SUT_IP" == "172.17.0.33" ]]; then export SUT_ID=${TRINODE_ID3}; fi 
}

setup() {
  get_ID_node
}

@test 'Gridinit - Status of services' {
  run docker exec -ti ${SUT_ID} /usr/bin/gridinit_cmd status
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'Cluster - Status ' {
  run docker exec -ti ${SUT_ID} bash -c 'openio cluster list -c Up -f csv --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
  [[ ! "${output}" =~ "False" ]]
}

@test 'Cluster - Score unlock' {
  run docker exec -ti ${SUT_ID} bash -c 'openio cluster list -c Score -f csv --oio-ns OPENIO |sed -e "s@^@^@" |cat -evt'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
  [[ ! "${output}" =~ "^0$" ]]
}

@test 'OIO - push object' {
  run docker exec -ti ${SUT_ID} bash -c 'openio object create MY_CONTAINER /etc/passwd --oio-account MY_ACCOUNT --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - show object' {
  run docker exec -ti ${SUT_ID} bash -c 'openio container show MY_CONTAINER --oio-account MY_ACCOUNT --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - list objects' {
  run docker exec -ti ${SUT_ID} bash -c 'openio object list --oio-account MY_ACCOUNT MY_CONTAINER --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - Find the services involved for your container' {
  run docker exec -ti ${SUT_ID} bash -c 'openio container locate MY_CONTAINER --oio-account MY_ACCOUNT --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - Consistency' {
  md5orig=$(docker exec -ti ${SUT_ID} bash -c 'md5sum /etc/passwd | cut -d" " -f1')
  md5sds=$(docker exec -ti ${SUT_ID} bash -c 'openio object list --oio-account MY_ACCOUNT MY_CONTAINER -c Hash -f value --oio-ns OPENIO|tr [A-Z] [a-z]')
  run test "$md5orig" == "$md5sds"
  echo "md5orig: "$md5orig
  echo "md5sds: "$md5sds
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - Delete your object' {
  run docker exec -ti ${SUT_ID} bash -c 'openio object delete MY_CONTAINER passwd --oio-account MY_ACCOUNT --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - Delete your empty container' {
  run docker exec -ti ${SUT_ID} bash -c 'openio container delete MY_CONTAINER --oio-account MY_ACCOUNT --oio-ns OPENIO'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'AWS - Get credentials' {
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  run docker exec -ti ${SUT_ID} bash -c 'grep demo /root/.aws/credentials'
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'AWS - create bucket' {
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  run docker exec -ti ${SUT_ID} bash -c "aws --endpoint-url http://${SUT_IP}:6007 --no-verify-ssl s3 mb s3://mybucket"
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'AWS - upload into bucket' {
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  run docker exec -ti ${SUT_ID} bash -c "aws --endpoint-url http://${SUT_IP}:6007 --no-verify-ssl s3 cp /etc/passwd s3://mybucket"
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'AWS - Consistency' {
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  md5orig=$(docker exec -ti ${SUT_ID} bash -c 'md5sum /etc/passwd | cut -d" " -f1')
  docker exec -ti ${SUT_ID} bash -c "aws --endpoint-url http://${SUT_IP}:6007 --no-verify-ssl s3 cp s3://mybucket/passwd /tmp/passwd.aws"
  md5sds=$(docker exec -ti ${SUT_ID} bash -c 'md5sum /tmp/passwd.aws | cut -d" " -f1')
  run test "$md5orig" == "$md5sds"
  echo "md5orig: "$md5orig
  echo "md5sds: "$md5sds
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'AWS - Delete your object' {
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  run docker exec -ti ${SUT_ID} bash -c "aws --endpoint-url http://${SUT_IP}:6007 --no-verify-ssl s3 rm s3://mybucket/passwd"
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'AWS - Delete your empty bucket' {
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  run docker exec -ti ${SUT_ID} bash -c "aws --endpoint-url http://${SUT_IP}:6007 --no-verify-ssl s3 rb s3://mybucket"
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
}

@test 'OIO - Delete accounts' {
  run docker exec -ti ${SUT_ID} bash -c "openio account delete MY_ACCOUNT --oio-ns OPENIO"
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]
  if [[ "$VERSION" == "16.04" ]]; then skip; fi
  run docker exec -ti ${SUT_ID} bash -c "openio account delete AUTH_demo --oio-ns OPENIO"
  echo "output: "$output
  echo "status: "$status
  [[ "${status}" -eq "0" ]]

}



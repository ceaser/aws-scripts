#!/bin/bash

set -x
LOG_PATH=/root/user-data.sh
exec &> >(tee -a "$LOG_PATH")

mkdir /mnt/bitcoin /mnt/zcash
echo "/dev/mapper/vg--bitcoin-lvol0   /mnt/bitcoin/  ext3    defaults        0       0" >> /etc/fstab
echo "/dev/mapper/vg--zcash-lvol0     /mnt/zcash     ext3    defaults        0       0" >> /etc/fstab

while true
do
  ls /dev/mapper/vg--bitcoin-lvol0
  [ "$?" == "0" ] && break
  sleep 5
done

mount /mnt/bitcoin
if [ "$?" == "0" ]
then
  chgrp adm /mnt/bitcoin/ && chmod g+w /mnt/bitcoin/
  [ "$?" != "0" ] && exit

  ln -sf /mnt/bitcoin/bitcoin /home/ubuntu/.bitcoin
  [ "$?" != "0" ] && exit

  # Download Bitcoin
  bitcoin=bitcoin-0.15.1-x86_64-linux-gnu.tar.gz
  rm -rf /tmp/$bitcoin && \
    wget -O /tmp/$bitcoin https://bitcoincore.org/bin/bitcoin-core-0.15.1/bitcoin-0.15.1-x86_64-linux-gnu.tar.gz

  (
  cat <<EOP
387c2e12c67250892b0814f26a5a38f837ca8ab68c86af517f975a2a2710225b  /tmp/bitcoin-0.15.1-x86_64-linux-gnu.tar.gz
EOP
  ) > /tmp/$bitcoin.sha256
  [ "$?" != "0" ] && exit

  # Install Bitcoin
  pushd /tmp && \
  tar zxf $bitcoin && \
  cd `find . -type d -name "bitcoin*" 2>/dev/null` && \
  cp -R bin/* /usr/local/bin/ && \
  cp -R include/* /usr/local/include/ && \
  cp -R lib/* /usr/local/lib/ && \
  cp -R share/* /usr/local/share/ && \
  popd && \
  rm -rf /tmp/bitcoin*
  [ "$?" != "0" ] && exit

  # Setup systemd
  mkdir /etc/bitcoind && \
    ln -s /mnt/bitcoin/etc/bitcoind/env /etc/bitcoind/env && \
    ln -s /mnt/bitcoin/etc/systemd/system/bitcoind.service /etc/systemd/system/bitcoind.service
  [ "$?" != "0" ] && exit

  systemctl daemon-reload & systemctl start bitcoind.service
  echo 'alias b=bitcoin-cli' >> /home/ubuntu/.bashrc

fi

while true
do
  ls /dev/mapper/vg--zcash-lvol0
  [ "$?" == "0" ] && break
  sleep 5
done

mount /mnt/zcash
if [ "$?" == "0" ]
then
  chgrp adm /mnt/zcash/ && chmod g+w /mnt/zcash/
  [ "$?" != "0" ] && exit

  ln -sf /mnt/zcash/zcash-params /home/ubuntu/.zcash-params
  [ "$?" != "0" ] && exit

  ln -sf /mnt/zcash/zcash /home/ubuntu/.zcash
  [ "$?" != "0" ] && exit

  # Install zcash
  apt-get install apt-transport-https && \
    wget -qO - https://apt.z.cash/zcash.asc | apt-key add - && \
    echo "deb [arch=amd64] https://apt.z.cash/ jessie main" >> /etc/apt/sources.list.d/zcash.list && \
    apt-get update && apt-get install -y zcash
  [ "$?" != "0" ] && exit


  # Setup systemd
  mkdir /etc/zcashd && \
    ln -s /mnt/zcash/etc/zcashd/env /etc/zcashd/env && \
    ln -s /mnt/zcash/etc/systemd/system/zcashd.service /etc/systemd/system/zcashd.service
  [ "$?" != "0" ] && exit

  systemctl daemon-reload & systemctl start zcashd.service
  echo 'alias z=zcash-cli' >> /home/ubuntu/.bashrc
fi


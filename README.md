get-cartodb
===========

Stand up CartoDB on an Ubuntu 12.04 Vagrant box.

Many thanks to the [instructions](https://gist.github.com/ericmagnuson/5853638) [followed](https://gist.github.com/arjendk/6080388).

To run:

```shell
git clone https://github.com/albert-decatur/get-cartodb
cd get-cartodb
vagrant box add cartodb https://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box
vagrant init cartodb
vagrant up
vagrant ssh
```

Now in your vagrant box

```shell
bash /vagrant/get_cartodb.sh
# magic happens here - ie some config steps
bash /vagrant/run_cartodb.sh
```



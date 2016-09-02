Autoscaling Zookeeper Docker Container! 
=======================================

I don't know all the mechanics behind zookeeper & there're obviously tons of config parameters i'm missing. Yet, it seems to autoscale, thanks to consul & consul-template.

First working iteration

```shell
$ docker-compose up -d --build
...
$ for i in $(docker-compose ps -q zk); do echo "---node $i:"; docker exec $i sh -c 'echo "mntr" | nc 127.0.0.1 2181'; echo '-----------'; done  
---node 02b706fd97f61e3bc3b0a8f8d1c8c66d0bdc37c2c35b5b300f202c743c439d33:
zk_version      3.4.8--1, built on 02/06/2016 03:18 GMT
zk_avg_latency  0
zk_max_latency  0
zk_min_latency  0
zk_packets_received     1
zk_packets_sent 0
zk_num_alive_connections        1
zk_outstanding_requests 0
zk_server_state standalone
zk_znode_count  4
zk_watch_count  0
zk_ephemerals_count     0
zk_approximate_data_size        27
zk_open_file_descriptor_count   25
zk_max_file_descriptor_count    1048576
-----------
$ docker-compose scale zk=3
Creating and starting zookeeperconsultemplate_zk_3 ... done
Creating and starting zookeeperconsultemplate_zk_4 ... done
...
$ for i in $(docker-compose ps -q zk); do echo "---node $i:"; docker exec $i sh -c 'echo "mntr" | nc 127.0.0.1 2181'; echo '-----------'; done  

---node 6cddde500ccd2322b87dcdba9b1f95138c13328795fee137d570942cfdf9aa31:
zk_version      3.4.8--1, built on 02/06/2016 03:18 GMT
zk_avg_latency  0
zk_max_latency  0
zk_min_latency  0
zk_packets_received     1
zk_packets_sent 0
zk_num_alive_connections        1
zk_outstanding_requests 0
zk_server_state follower
zk_znode_count  4
zk_watch_count  0
zk_ephemerals_count     0
zk_approximate_data_size        27
zk_open_file_descriptor_count   29
zk_max_file_descriptor_count    1048576
-----------
---node 4a532b29cf3954691ba840c5416d3135aa957082605f1026aa541325b4958017:
zk_version      3.4.8--1, built on 02/06/2016 03:18 GMT
zk_avg_latency  0
zk_max_latency  0
zk_min_latency  0
zk_packets_received     1
zk_packets_sent 0
zk_num_alive_connections        1
zk_outstanding_requests 0
zk_server_state follower
zk_znode_count  4
zk_watch_count  0
zk_ephemerals_count     0
zk_approximate_data_size        27
zk_open_file_descriptor_count   29
zk_max_file_descriptor_count    1048576
-----------
---node 2e83ae53a38fd66f4074d12ca425a83db1eba0e04ad86c4ee6d1d1b923c89545:
zk_version      3.4.8--1, built on 02/06/2016 03:18 GMT
zk_avg_latency  0
zk_max_latency  0
zk_min_latency  0
zk_packets_received     1
zk_packets_sent 0
zk_num_alive_connections        1
zk_outstanding_requests 0
zk_server_state leader
zk_znode_count  4
zk_watch_count  0
zk_ephemerals_count     0
zk_approximate_data_size        27
zk_open_file_descriptor_count   31
zk_max_file_descriptor_count    1048576
zk_followers    2
zk_synced_followers     2
zk_pending_syncs        0
-----------
$ ...
```


Don't support : Rolling restart ;)
whenever a node popsup, every other nodes are restarted by consul-template at the same time, which can result in a global unavailability of the zk cluster.


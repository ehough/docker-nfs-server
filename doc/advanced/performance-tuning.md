# Performance tuning

The following tips might improve your NFS server's performance.

* Set the **`NFS_SERVER_THREAD_COUNT`** environment variable to control how many server threads `rpc.nfsd` will use. A good minimum is one thread per CPU core, but 4 or 8 threads per core is probably better. The default is one thread per CPU core. 
  
* Running the container with `--network host` *might* improve network performance by 10% - 20% [[1](https://jtway.co/docker-network-performance-b95bce32b4b9),[2](https://www.percona.com/blog/2016/08/03/testing-docker-multi-host-network-performance/)], though this hasn't been tested.
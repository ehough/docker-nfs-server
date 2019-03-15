# Performance tuning

The NFS server itself requires very little tuning; out-of-the-box it's blazingly fast even under high loads. You'll find that most performance gains will come from setting both the appropriate [mount options](https://linux.die.net/man/5/nfs) in your clients as well as the right [export options](https://linux.die.net/man/5/exports) on your shared filesystems. 

That said, the following tips might improve your NFS server's performance.

* Set the **`NFS_SERVER_THREAD_COUNT`** environment variable to control how many server threads `rpc.nfsd` will use. A good minimum is one thread per CPU core, but 4 or 8 threads per core is probably better. The default is one thread per CPU core. 
  
* Running the container with `--network host` *might* improve network performance by 10% - 20% on a heavily-loaded server [[1](https://jtway.co/docker-network-performance-b95bce32b4b9),[2](https://www.percona.com/blog/2016/08/03/testing-docker-multi-host-network-performance/)], though this hasn't been tested.
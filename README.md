# Using Singularity with Mahtis MPI communication stack

Documentation of building and using singularity containers equipped with intel-mpi-benchmark. The build process would most likely be similar for any software built into a Singularity container.

## Building intel-mpi-benchmark with singularity

The build process is done in 2 parts

1. Building container with openmpi
2. Building container with intel MPI Benchmark based off of openmpi container.

This structure allows us to have an independent compartmentalized openmpi container which we can "clone" to build containerized software. Thus we do not need to build openmpi every time we make changes to the software that utilizes it. 

Note: The singularity container build process e.g. building software from source can sometimes take quite a while.

### 1. Building openmpi container

This build process uses miniconda for installing openmpi. I'm  sure that downloading openmpi from source would work as well.

<details><summary>conda_mpi_4.0.3.def</summary>

```
Bootstrap: docker
From: registry.access.redhat.com/ubi7/ubi:7.9

%post
    yum -y install wget
    cd /
    mkdir MPI
    cd MPI
    wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.9.2-Linux-x86_64.sh
    bash Miniconda3-py39_4.9.2-Linux-x86_64.sh -b -p $(readlink -f miniconda3)
    miniconda3/bin/conda install -c conda-forge openmpi-mpicc==4.0.3
    miniconda3/bin/conda install -c conda-forge openmpi-mpicxx==4.0.3
    miniconda3/bin/conda install -c conda-forge openmpi-mpifort==4.0.3
```

</details>

Simply run the command below to produce the singularity container that is equiped with openmpi-4.0.3
    
    singularity build conda_mpi_4.0.3.sif conda_mpi_4.0.3.def

### 2. Building intel-mpi-benchmark container

Next we will create the container with the actual software that we would like to run. This build process has a few notable parts. 

The bootstrap this time around is marked as localimage. The image this time around will be the conda_mpi_4.0.3.sif that we created earlier. 

<details><summary>intel_mpi_benchmark.def</summary>

```
Bootstrap: localimage
From: conda_mpi_4.0.3.sif

%post
    yum -y install make
    yum -y install wget
    yum -y install git

    mkdir /software
    cd /software

    git clone https://github.com/intel/mpi-benchmarks.git
    export PATH="$PATH:/MPI/miniconda3/bin"
    export CC="mpicc -Wl,--as-needed"
    export CXX="mpicxx -Wl,--as-needed"
    export LDFLAGS="-Wl,--as-needed"
    cd mpi-benchmarks/
    make

    rm -rf /MPI
```

</details>

Building software works in a similar fashion as it would while building from source in a terminal. We need to of course export the path to mpi compilers before any compilation. 

`-Wl,--as-needed` is a necessary addition. This is due to the fact that mpi compilers will build all and everything available to it. **This can cause problems later on, since for example c++ libraries for MPI are not found on Mahti**. When running the container on mahti, we will recieve a nice error that some cxx libraries are missing. With the aforementioned flag we can simply build with only the necessities. Exporting just the LDFLAGS might not be enough depending on the software's make file and build process. Any given make file needs to be respectively modified. Of course this is as simple as adding  `-Wl,--as-needed` anywhere and everywhere you can. 

Lastly we remove the MPI build from the container. This is also related to the stack of Mahti. While running the container we want to use the MPI stack of the system we are running on, and not the container. With this we minimise any overhead, and allow the program to run as close to the hardware as possible.

Similarly as before we run the command below to build the container:

    singularity build intel_mpi_benchmark.sif intel_mpi_benchmark.def

## Using MPI singularity containers with Mahti

Now that we have created our container, we can start using it on Mahti. For minimal overhead we want to employ the heuristics of the systems MPI communication stack instead of the MPI used while compiling the software in the container. This is why we deleted all traces of the MPI stack so that srun doesn't resort to it.

Generally while running a singularity container with MPI the execution would be as such

    mpirun -n <NUMBER_OF_RANKS> singularity exec <PATH/TO/MY/IMAGE> </PATH/TO/BINARY/WITHIN/CONTAINER>

But since we are suing a batch system, we will use srun. The execution line in the batch file will be then

    srun singularity exec <PATH/TO/MY/IMAGE> </PATH/TO/BINARY/WITHIN/CONTAINER>

But since we are using a container we need to link the mpi stack to the container manually. This is done with an extra intermediate script which can also be just pasted directly to the batch file.

<details><summary>link_mpi_mahti.sh</summary>

```
#!/bin/bash
function add_bind (){
    BIND_FLAGS="$BIND_FLAGS -B $1:$1"
}

module load openmpi/4.0.3

add_bind /appl/spack
add_bind /appl/opt/ucx
add_bind /appl/opt/hcoll
add_bind /usr/lib64/libevent-2.0.so.5 
add_bind /usr/lib64/libevent_core-2.0.so.5 
add_bind /usr/lib64/libevent_pthreads-2.0.so.5
add_bind /usr/lib64/libhwloc.so.5 
add_bind /usr/lib64/libibverbs.so.1 
add_bind /usr/lib64/liblustreapi.so.1 
add_bind /usr/lib64/libpmix.so.2 
add_bind /usr/lib64/librdmacm.so.1 
add_bind /usr/lib64/libltdl.so.7
add_bind /usr/share/pmix/
add_bind /usr/bin/strace
add_bind /etc/pmix-mca-params.conf
add_bind /usr/lib64/pmix/
add_bind /usr/lib64/libibverbs
add_bind /usr/lib64/mlnx_ofed
add_bind /usr/lib64/libmlx5.so.1
add_bind /lib64/libnl-3.so.200
add_bind /lib64/libnl-route-3.so.200

singularity exec --env-file envs.txt $BIND_FLAGS intel_mpi_benchmark.sif /software/mpi-benchmarks/IMB-MPI1
```

The envs.txt file contains a few more environment variables:

```
export LD_LIBRARY_PATH
export PMIX_MCA_gds=hash
export UCX_TLS=ib,posix,self 
export UCX_LOG_LEVEL=DEBUG
```

</details>

All and all, your batch file can look something like this

<details><summary>batch.sh</summary>

```
#!/bin/bash

#SBATCH --job-name=generic_job_name
#SBATCH --account=project_xxxxxxx
#SBATCH --time=01:00:00
#SBATCH --partition=medium
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128

module purge
module load gcc/9.3.0
module load openmpi/4.0.3

srun link_mpi_mahti.sh
```

</details>

## Notes about dependencies

The OpenMPI container is equipped with GCC-7, this is not a problem when building C programs since GCC 7 is compatible with GCC 9. Nonetheless with Fortran programs this is an issue. Thus the original conda_mpi_4.0.3.sif container will not be viable. Below is a .def file that can produce a singularity container with GCC/10.3.0 and OpenMPI/4.1.0. This is the container that I built CloverLeaf on top of. 

</details>

This container uses the identical stack as built on Mahti, thus you will need mahti build cache to be able to produce this container. The cache should be available at "/scratch/project_2001659/nortamoh/cache.tar.gz" on Mahti

<details>
<summary>gcc-10_mpi-4.1.0.def</summary>

```
Bootstrap: docker
From: registry.access.redhat.com/ubi7/ubi:7.9

%files
    mirrors.yaml mirrors.yaml
    cache.tar.gz /cache.tar.gz
    packages.yaml packages.yaml
%post 
    yum -y install tar
    yum -y install wget
    yum -y install bzip2
    yum -y install git
    yum -y install gcc
    yum -y install patch
    yum -y install file
    wget https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/p/patchelf-0.12-1.el7.x86_64.rpm
    rpm -Uvh patchelf*rpm
    yum -y install patchelf
    yum -y install libnl3

    cd / && tar -xvf /cache.tar.gz
    chgrp -R root /mahti_build_cache
    chown -R root /mahti_build_cache
    chmod -R o+rx /mahti_build_cache

    git clone https://github.com/spack/spack.git /spack
    source /spack/share/spack/setup-env.sh
    cp mirrors.yaml  /spack/etc/spack/defaults/mirrors.yaml
    cp packages.yaml  /spack/etc/spack/defaults/packages.yaml 
    
    cd /mahti_build_cache 
    spack buildcache update-index
    spack buildcache install -uo gcc
    spack compiler add $(dirname "$(find /spack/opt/spack/linux-rhel7-x86_64/ -name "gcc"  | grep bin)")
    cp ~/.spack/linux/compilers.yaml /spack/etc/spack/defaults/compilers.yaml
    spack buildcache install -uo openmpi@4.1.0

    rm -rf /mahti_build_cache
```

</details>

## Performance

Actual performance results will be available in the ![benchmark-results](https://gitlab.ci.csc.fi/compen/hpc-support/benchmark-results/-/tree/master/singularity-mpi) repository. 

So far the overhead for a single unit operation is minimal, with larger memory communication the unit overhead accumulates, but the error is not significant. Or at least it is insignificant enough, such that there is promise in using a singularity container in HPC applications. Most of the differences can be clumped up to normal error and fluctuation between runs.

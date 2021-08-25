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

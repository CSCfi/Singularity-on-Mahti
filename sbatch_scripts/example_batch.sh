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

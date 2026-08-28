#!/usr/bin/env bash
# sbatch wrapper for the apptainer build (kept out of pull_sif.sh because local
# login-node builds hit the interactive-session 24GB memory cap).
#
# Usage: sbatch build_slurm.sh
#SBATCH --job-name=wgd-container
#SBATCH --output=build.log
#SBATCH --error=build.err
#SBATCH --partition=short
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -eu

module load apptainer
./pull_sif.sh
echo "BUILD DONE: $(ls -la wgd-*.sif)"

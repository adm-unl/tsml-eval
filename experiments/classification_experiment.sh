#!/bin/bash
# Start and end for resamples
max_folds=30
start_fold=1
# To avoid dumping 1000s of jobs in the queue we have a higher level queue
maxNumSubmitted=700
# queue options are https://my.uea.ac.uk/divisions/it-and-computing-services/service-catalogue/research-it-services/hpc/ada-cluster/using-ada
queue="compute-64-512"
username="ajb"
mail="NONE"
mailto="ajb@uea.ac.uk"
# MB for jobs, max is maybe 64000 before you need ot use huge memory queue
max_memory=8000
# Max allowable is 7 days  - 168 hours
max_time="168:00:00"
# Not sure what this does, it relates
start_point=1
# Tony's work space, all should be able to read these.
# Change if you want to use different data or lists
data_dir="/gpfs/home/ajb/Data/"
datasets="/gpfs/home/ajb/DataSetLists/temp.txt"
# Put your home directory here
local_path="/gpfs/home/ajb/"
# Change these to reflect your own file structure
results_dir=$local_path"ClassificationResults/MultivariateReferenceResults/sktime/"
out_dir=$local_path"Code/output/multivariate/"
script_file_path=$local_path"Code/estimator-evaluation/sktime_estimator_evaluation/experiments/classification_experiments.py"
# Env set up, see https://hackmd.io/ds5IEK3oQAquD4c6AP2xzQ
env_name="sktime-dev"
# Generating train folds is usually slower, set to false unless you need them.
generate_train_files="true"
# If set for true, looks for <problem>_Train<fold>.ts file
predefined_folds="false"

# List valid classifiers e.g DrCIF TDE Arsenal STC MUSE ROCKET Mini-ROCKET Multi-ROCKET  ROCKET Mini-ROCKET Multi-ROCKET
count=0
while read dataset; do
for classifier in STC
do

# This is the loop to keep from dumping everything in the queue which is maintained around maxNumSubmitted jobs
numPending=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "PD ${queue}" | wc -l)
numRunning=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "R ${queue}" | wc -l)
while [ "$((numPending+numRunning))" -ge "${maxNumSubmitted}" ]
do
    echo Waiting 30s, $((numPending+numRunning)) currently submitted on ${queue}, user-defined max is ${maxNumSubmitted}
	sleep 30
	numPending=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "PD ${queue}" | wc -l)
	numRunning=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "R ${queue}" | wc -l)
done

((count++))

if ((count>=start_point)); then

mkdir -p ${out_dir}${classifier}/${dataset}/
# his creates the scrip to run the job based on the info above
echo "#!/bin/bash
#SBATCH --qos=ht
#SBATCH --mail-type=${mail}
#SBATCH --mail-user=${mailto}
#SBATCH -p ${queue}
#SBATCH -t ${max_time}
#SBATCH --job-name=${classifier}${dataset}
#SBATCH --array=${start_fold}-${max_folds}
#SBATCH --mem=${max_memory}M
#SBATCH -o ${out_dir}${classifier}/${dataset}/%A-%a.out
#SBATCH -e ${out_dir}${classifier}/${dataset}/%A-%a.err

. /etc/profile

module add python/anaconda/2019.10/3.7
source /gpfs/software/ada/python/anaconda/2019.10/3.7/etc/profile.d/conda.sh
conda activate $env_name
export PYTHONPATH=$(pwd)
# Input args to classification_experiments are in main method of
# https://github.com/uea-machine-learning/estimator-evaluation/blob/main/sktime_estimator_evaluation/experiments/classification_experiments.py
python ${script_file_path} ${data_dir} ${results_dir} ${classifier} ${dataset} \$SLURM_ARRAY_TASK_ID ${generate_train_files} ${predefined_folds}"  > generatedFile.sub

echo ${count} ${classifier}/${dataset}

sbatch < generatedFile.sub --qos=ht
fi

done
done < ${datasets}

echo Finished submitting jobs
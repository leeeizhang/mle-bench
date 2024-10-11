#!/bin/bash
set -x # Print commands and their arguments as they are executed

cd ${AGENT_DIR}

eval "$(conda shell.bash hook)" # make conda available to the shell
conda activate agent

# determine hardware available
if command -v nvidia-smi &> /dev/null && nvidia-smi --query-gpu=name --format=csv,noheader &> /dev/null; then
  HARDWARE=$(nvidia-smi --query-gpu=name --format=csv,noheader \
    | sed 's/^[ \t]*//' \
    | sed 's/[ \t]*$//' \
    | sort \
    | uniq -c \
    | sed 's/^ *\([0-9]*\) *\(.*\)$/\1 \2/' \
    | paste -sd ', ' -)
else
  HARDWARE="a CPU"
fi
export HARDWARE
# check that we can use the GPU in PyTorch
python -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'WARNING: No GPU')"
# check that we can use the GPU in TensorFlow
python -c "import tensorflow as tf; print('GPUs Available: ', tf.config.list_physical_devices('GPU'))"

# build mle project
ln -s ${LOGS_DIR} ${AGENT_DIR}/logs
ln -s ${CODE_DIR} ${AGENT_DIR}/workspaces
ln -s ${SUBMISSION_DIR} ${AGENT_DIR}/submission

mkdir -p ${AGENT_DIR}/workspace/.mle/
cat > ${AGENT_DIR}/workspace/.mle/project.yml << EOF
api_key: ${OPENAI_API_KEY}
integration: {}
platform: OpenAI
search_key: ''
EOF

pushd ${AGENT_DIR}/workspace/

# run with timeout, and print if timeout occurs
timeout $TIME_LIMIT_SECS \
mle kaggle \
  --data "/home/data/" \
  --requirement "/home/data/description.md" \
  --submission ${AGENT_DIR}/submission \
  --competition ${COMPETITION_ID} \
  $@ # forward the bash arguments to aide
if [ $? -eq 124 ]; then
  echo "Timed out after $TIME_LIMIT"
fi

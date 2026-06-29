# local machine
## step 1: set up the environment
```bash
cd $(git rev-parse --show-toplevel)
conda create -n gpt2_finetune python=3.8 -y
conda activate gpt2_finetune
pip install -r mds_proj/src/requirements.txt
pip install kaggle peft
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126
else
    pip3 install torch torchvision
fi
```


## step 2: download the dataset
```bash
cd $(git rev-parse --show-toplevel)
kaggle datasets download jonery/finetuning-dataset -p mds_proj/src/data --unzip && mv mds_proj/src/data/src/* mds_proj/src/data/ && rm -rf mds_proj/src/data/src
```


## step 3: run the training code
```bash
cd $(git rev-parse --show-toplevel)/mds_proj/src
python train_sft.py --model-type gpt2-medium --pretrain huggingface --batch-size 1 --exp-name lora_ft_exp --use-lora --max-steps 1000
```

# cloud platform(kaggle) 
directly execute the main code in the notebook [main.ipynb](../mds_proj/main.ipynb)
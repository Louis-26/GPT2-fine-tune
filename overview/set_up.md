# step 1: set up the environment
```bash
cd $(git rev-parse --show-toplevel)
conda create -n gpt2_finetune python=3.8 -y
conda activate gpt2_finetune
pip install -r mds_proj/src/requirements.txt
pip install kaggle
```


# step 2: download the dataset
```bash
cd $(git rev-parse --show-toplevel)
kaggle datasets download jonery/finetuning-dataset /mds_proj/src/data --unzip
```
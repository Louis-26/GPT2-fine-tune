# Overview
This project aims conduct fine-tuning on GPT-2 model with HH-RLHF dataset from Anthropic.

# Dataset
With the full name as `Helpful and Harmless - Reinforcement Learning from Human Feedback`, this dataset `HH-RLHF` aims to adjust the model ability to provide more helpful and harmless responses.

HH-RLHF dataset with the source [here](https://huggingface.co/datasets/Anthropic/hh-rlhf)
- training dataset: 43835 samples
- test dataset: 2354 samples

You can also download the dataset from [here](https://drive.google.com/uc?id=1ECmnL9A97qiGBIaYBLoChD9Mb1XYL76u&export=download)


# Model
By default, we use `gpt2-medium` is selected for training and fine-tuning. 

# Training
open kaggle, open [main code](./mds_proj/main.ipynb)
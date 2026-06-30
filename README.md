# Overview
This project aims conduct fine-tuning on GPT-2 model with HH-RLHF dataset from Anthropic.

# Dataset
With the full name as `Helpful and Harmless - Reinforcement Learning from Human Feedback`, this dataset `HH-RLHF` aims to adjust the model ability to provide more helpful and harmless responses.

HH-RLHF dataset with the source [here](https://huggingface.co/datasets/Anthropic/hh-rlhf)
- training dataset: 43835 samples
- test dataset: 2354 samples

You can also download the dataset from [here](https://www.kaggle.com/datasets/louis26/hhrlhf-dataset)


# Model
By default, we use `gpt2-medium` is selected for training and fine-tuning. 

# Computing Resources
I used Telsa T4 GPU on kaggle, but a more powerful GPU is preferred for more efficient training.

# Training
open kaggle, open [main code](./mds_proj/kaggle_execution_notebook.ipynb)

# Evaluation Metric
- Semantic Similarity: We use the `sentence-transformers` library to compute the cosine similarity between the model's output and the reference result.
- LLM-as-a-judge: We use the `gpt-4o-mini` to evaluate the model's output by asking the model to provide a score between 0-10.
  
# Performance
## 📊 Experimental Results & Performance Benchmark


| Model | Tuning Strategy | Trainable Params | Training Time | STS Score | LLM Judge Score (1-10) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **GPT-2 Base** | Pre-trained Only | 0 (Frozen) | - | 0.036 | 2.17 |
| **GPT-2 + FFT** | Full Fine-Tuning | 407M (100%) | 10,918 s | 0.046 | **2.82** |
| **GPT-2 + LoRA** | Low-Rank Adaptation ($r=8$) | **786K (0.19%)** | **7,246 s** | **0.066** | 2.73 |

## 🚀 Key Takeaways:
- **Parameter Efficiency:** LoRA ($r=8$) successfully reduced the trainable parameters by **99.8%** compared to FFT.
- **Computational Speed:** LoRA training was **33.6% faster** than FFT while maintaining an extremely low memory footprint.
- **Alignment Improvement:** The LoRA-adapted model exhibited a massive **83.3% improvement in STS** and a **25.8% boost in contextual dialogue abilities** (LLM Judge Score) over the un-tuned base model, achieving parity with the heavy FFT approach. Meanwhile, LoRA's performance is competitive with FFT with average judge score and even superior in STS score compared with full fine tuning, despite using a fraction of the parameters.
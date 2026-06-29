import click
import torch
from trainers import SFTTrainer
from gpt import GPT
from dataset import EYLSFTStaticDataset
from configs import get_configs

# Import PEFT library for LoRA
from peft import LoraConfig, get_peft_model, TaskType

# Avoid GPU version conflict (For Kaggle GPU only). Comment below two lines if you use local machine in order to speed up training.
import torch._dynamo.config
torch._dynamo.config.suppress_errors = True

def train(pretrain, batch_size, exp_name, use_lora, model_type, max_steps):
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    
    cfg = get_configs(model_type) # change this line to select different models
    cfg.max_steps = max_steps if max_steps else 200000 // batch_size
    cfg.batch_size = batch_size
    cfg.pretrain = pretrain
    assert pretrain == "huggingface" # make sure the pretrained model is in the format of huggingface.
    cfg.exp_name = exp_name

    # load the pretrained GPT model based on the configuration
    model = GPT.from_pretrained(cfg)
    
    if use_lora:
        print(f"🚀 [INFO] Enabling LoRA fine-tuning mode for {model_type}...")
        lora_config = LoraConfig(
            r=8,
            lora_alpha=32,
            lora_dropout=0.1,
            # Note: Ensure "c_attn" matches the exact name of the attention 
            # projection layer defined in your custom GPT class.
            target_modules=["qkv_projection"], 
        )
        # Wrap the original model with the PEFT (LoRA) configuration
        model = get_peft_model(model, lora_config)
        
        # Print the ratio of trainable parameters (should be < 1%)
        model.print_trainable_parameters()
    else:
        print(f"⚠️ [WARNING] Enabling Full Fine-Tuning (FFT) mode for {model_type}.")
        print("⚠️ [WARNING] All parameters are trainable. Watch out for Out-Of-Memory (OOM) errors!")
    
    # load SFT dataset
    train_ds = EYLSFTStaticDataset(block_size=1024,
                                   split='train',
                                   max_examples=None,
                                   tokenizer_name="tiktoken/gpt2")
    test_ds = EYLSFTStaticDataset(block_size=1024,
                                  split='test',
                                  max_examples=None,
                                  tokenizer_name="tiktoken/gpt2")
    
    trainer = SFTTrainer(cfg, device, model, train_ds, test_ds)
    trainer.fit()


@click.command()
@click.option('--model-type', '-m', default="gpt2-medium", help="Specify the model configuration (e.g., gpt2, gpt2-medium, gpt2-large).")
@click.option('--pretrain', '-p', default="huggingface", help="Pretrained model format.")
@click.option('--batch-size', '-b', default=1, help="Batch size per GPU.")
@click.option('--exp-name', '-n', default="default", help="Name of the experiment for logging.")
@click.option('--use-lora', is_flag=True, help="Pass this flag to enable LoRA parameter-efficient fine-tuning.")
@click.option('--max-steps', '-s', type=int, default=None, help="Maximum training steps. If not set, defaults to 200000 // batch_size.")

def main(pretrain, batch_size, exp_name, use_lora, model_type, max_steps):
    torch.manual_seed(1234)
    train(pretrain, batch_size, exp_name, use_lora, model_type, max_steps)


if __name__ == "__main__":
    main()

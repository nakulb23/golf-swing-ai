"""
GolfCaddy-1B Fine-Tuning Script

Fine-tunes TinyLlama 1.1B on golf-specific Q&A data using QLoRA.
Optimized for Google Colab with T4 GPU (free tier).

Usage:
    python finetune_golf_llm.py --data golf_training_data_training.json --output golfcaddy-1b

Requirements:
    pip install transformers datasets peft bitsandbytes accelerate trl
"""

import json
import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    BitsAndBytesConfig
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from trl import SFTTrainer
import argparse
from typing import Dict, List

class GolfLLMTrainer:
    """Fine-tune TinyLlama for golf expertise"""

    def __init__(
        self,
        base_model: str = "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
        output_dir: str = "golfcaddy-1b",
        max_length: int = 512
    ):
        self.base_model = base_model
        self.output_dir = output_dir
        self.max_length = max_length
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        print(f"🏌️ Initializing GolfCaddy-1B training")
        print(f"📱 Device: {self.device}")
        print(f"📦 Base model: {base_model}")

    def load_training_data(self, data_file: str) -> Dataset:
        """Load and prepare training data"""
        print(f"📂 Loading training data from {data_file}...")

        with open(data_file, 'r') as f:
            data = json.load(f)

        print(f"✅ Loaded {len(data)} training examples")

        # Convert to HuggingFace Dataset
        dataset = Dataset.from_dict({
            'instruction': [item['instruction'] for item in data],
            'input': [item['input'] for item in data],
            'output': [item['output'] for item in data],
            'category': [item['category'] for item in data]
        })

        return dataset

    def format_prompt(self, example: Dict) -> str:
        """Format training examples in TinyLlama chat format"""
        # TinyLlama chat template
        prompt = f"""<|system|>
{example['instruction']}</s>
<|user|>
{example['input']}</s>
<|assistant|>
{example['output']}</s>"""

        return prompt

    def setup_model_and_tokenizer(self):
        """Load model with QLoRA configuration"""
        print("🔧 Setting up model and tokenizer...")

        # 4-bit quantization config for memory efficiency
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16
        )

        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.base_model,
            trust_remote_code=True
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        self.tokenizer.padding_side = "right"

        # Load model with quantization
        model = AutoModelForCausalLM.from_pretrained(
            self.base_model,
            quantization_config=bnb_config,
            device_map="auto",
            trust_remote_code=True
        )

        # Prepare for k-bit training
        model = prepare_model_for_kbit_training(model)

        # LoRA configuration
        lora_config = LoraConfig(
            r=16,  # LoRA rank
            lora_alpha=32,  # LoRA alpha
            target_modules=[
                "q_proj",
                "k_proj",
                "v_proj",
                "o_proj",
                "gate_proj",
                "up_proj",
                "down_proj"
            ],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )

        # Apply LoRA
        model = get_peft_model(model, lora_config)
        model.print_trainable_parameters()

        self.model = model

        print("✅ Model and tokenizer ready")

    def train(self, dataset: Dataset, epochs: int = 3, batch_size: int = 4):
        """Fine-tune the model"""
        print(f"🚀 Starting training...")
        print(f"  Epochs: {epochs}")
        print(f"  Batch size: {batch_size}")
        print(f"  Total examples: {len(dataset)}")

        # Training arguments optimized for Colab T4
        training_args = TrainingArguments(
            output_dir=self.output_dir,
            num_train_epochs=epochs,
            per_device_train_batch_size=batch_size,
            gradient_accumulation_steps=4,
            learning_rate=2e-4,
            fp16=True,
            save_strategy="epoch",
            logging_steps=10,
            optim="paged_adamw_8bit",
            warmup_steps=50,
            max_grad_norm=0.3,
            group_by_length=True,
            lr_scheduler_type="cosine",
            report_to="none"  # Disable wandb
        )

        # SFT Trainer (Supervised Fine-Tuning)
        trainer = SFTTrainer(
            model=self.model,
            train_dataset=dataset,
            args=training_args,
            formatting_func=self.format_prompt
        )

        # Train!
        print("\n🏋️ Training in progress...")
        trainer.train()

        print("✅ Training complete!")

        # Save final model
        self.model.save_pretrained(f"{self.output_dir}/final")
        self.tokenizer.save_pretrained(f"{self.output_dir}/final")

        print(f"💾 Model saved to {self.output_dir}/final")

    def merge_and_export(self, export_path: str = None):
        """Merge LoRA weights and export full model"""
        if export_path is None:
            export_path = f"{self.output_dir}/merged"

        print(f"🔄 Merging LoRA weights and exporting...")

        # Merge LoRA weights with base model
        merged_model = self.model.merge_and_unload()

        # Save merged model
        merged_model.save_pretrained(export_path)
        self.tokenizer.save_pretrained(export_path)

        print(f"✅ Merged model saved to {export_path}")
        print(f"📦 This model can now be converted to GGUF")

        return export_path

    def test_model(self, test_questions: List[str]):
        """Quick test of the trained model"""
        print("\n🧪 Testing model with sample questions...")

        self.model.eval()

        for question in test_questions:
            prompt = self.format_prompt({
                'instruction': 'You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately and helpfully.',
                'input': question,
                'output': ''  # Will be generated
            })

            # Tokenize
            inputs = self.tokenizer(
                prompt,
                return_tensors="pt",
                truncation=True,
                max_length=self.max_length
            ).to(self.device)

            # Generate
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=200,
                    temperature=0.7,
                    top_p=0.9,
                    do_sample=True
                )

            # Decode
            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)

            # Extract just the answer
            if '<|assistant|>' in response:
                answer = response.split('<|assistant|>')[-1].strip()
            else:
                answer = response

            print(f"\n❓ Q: {question}")
            print(f"💬 A: {answer}")
            print("-" * 80)

def main():
    """Main execution"""
    parser = argparse.ArgumentParser(description='Fine-tune TinyLlama for golf')
    parser.add_argument('--data', required=True, help='Training data JSON file')
    parser.add_argument('--output', default='golfcaddy-1b', help='Output directory')
    parser.add_argument('--epochs', type=int, default=3, help='Training epochs')
    parser.add_argument('--batch-size', type=int, default=4, help='Batch size')
    parser.add_argument('--test', action='store_true', help='Test after training')
    parser.add_argument('--export', action='store_true', help='Export merged model')

    args = parser.parse_args()

    # Initialize trainer
    trainer = GolfLLMTrainer(output_dir=args.output)

    # Load data
    dataset = trainer.load_training_data(args.data)

    # Setup model
    trainer.setup_model_and_tokenizer()

    # Train
    trainer.train(dataset, epochs=args.epochs, batch_size=args.batch_size)

    # Test
    if args.test:
        test_questions = [
            "Where should I place the ball if it lands on cart path?",
            "How do I fix my slice?",
            "What driver loft should I use for 95 mph swing speed?",
            "How do I read a breaking putt?",
            "What's the penalty for a lost ball?"
        ]
        trainer.test_model(test_questions)

    # Export merged model
    if args.export:
        merged_path = trainer.merge_and_export()
        print(f"\n✅ Ready for GGUF conversion!")
        print(f"Run: python convert_to_gguf.py {merged_path}")

    print("\n🎉 All done!")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Setup script for downloading and preparing AI models for local golf chatbot.
This script will download lightweight language models optimized for CPU inference.
"""

import os
import sys
import logging
from pathlib import Path
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import coremltools as ct
import numpy as np

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Model configurations (from smallest to largest)
MODELS = {
    "flan-t5-base": {
        "name": "google/flan-t5-base",
        "size": "250M",
        "description": "Very fast, good for basic responses",
        "cpu_optimized": True
    },
    "phi-2": {
        "name": "microsoft/phi-2", 
        "size": "2.7B",
        "description": "Best balance of quality and speed",
        "cpu_optimized": True,
        "recommended": True
    },
    "opt-1.3b": {
        "name": "facebook/opt-1.3b",
        "size": "1.3B", 
        "description": "Good quality, medium speed",
        "cpu_optimized": True
    },
    "pythia-1.4b": {
        "name": "EleutherAI/pythia-1.4b",
        "size": "1.4B",
        "description": "Alternative medium-size model",
        "cpu_optimized": True
    }
}

def check_system_requirements():
    """Check if system meets minimum requirements"""
    logger.info("Checking system requirements...")
    
    # Check Python version
    if sys.version_info < (3.8, 0):
        logger.error("Python 3.8+ required")
        return False
        
    # Check available memory
    try:
        import psutil
        memory_gb = psutil.virtual_memory().total / (1024**3)
        if memory_gb < 4:
            logger.warning(f"Low memory detected: {memory_gb:.1f}GB. Recommend 8GB+ for best performance")
        else:
            logger.info(f"Memory available: {memory_gb:.1f}GB")
    except ImportError:
        logger.warning("Cannot check memory (psutil not installed)")
    
    # Check PyTorch
    try:
        logger.info(f"PyTorch version: {torch.__version__}")
        logger.info(f"CUDA available: {torch.cuda.is_available()}")
        if torch.cuda.is_available():
            logger.info(f"CUDA device: {torch.cuda.get_device_name(0)}")
    except:
        logger.error("PyTorch not properly installed")
        return False
    
    return True

def download_model(model_key: str, models_dir: Path):
    """Download and prepare a specific model"""
    model_config = MODELS[model_key]
    model_name = model_config["name"]
    
    logger.info(f"Downloading {model_key} ({model_config['size']}) - {model_config['description']}")
    
    try:
        # Create model directory
        model_dir = models_dir / model_key
        model_dir.mkdir(exist_ok=True)
        
        # Download tokenizer
        logger.info("Downloading tokenizer...")
        tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            cache_dir=model_dir / "tokenizer",
            trust_remote_code=True
        )
        
        # Download model  
        logger.info("Downloading model (this may take a while)...")
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            cache_dir=model_dir / "model",
            torch_dtype=torch.float32,  # Use float32 for better CPU compatibility
            trust_remote_code=True,
            low_cpu_mem_usage=True
        )
        
        # Save locally
        model_path = model_dir / "pytorch_model"
        logger.info(f"Saving to {model_path}")
        tokenizer.save_pretrained(model_path / "tokenizer")
        model.save_pretrained(model_path / "model")
        
        # Optimize for CPU inference
        if model_config.get("cpu_optimized"):
            logger.info("Optimizing for CPU inference...")
            model.eval()
            
            # Try to convert to TorchScript for faster inference
            try:
                scripted_model = torch.jit.script(model)
                scripted_model.save(model_path / "model_scripted.pt")
                logger.info("Created TorchScript version for faster CPU inference")
            except Exception as e:
                logger.warning(f"Could not create TorchScript version: {e}")
        
        # Test the model
        logger.info("Testing model...")
        test_input = "What is golf?"
        inputs = tokenizer(test_input, return_tensors="pt")
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=50,
                temperature=0.7,
                do_sample=True,
                pad_token_id=tokenizer.pad_token_id or tokenizer.eos_token_id
            )
        
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        logger.info(f"Test response: {response[:100]}...")
        
        # Write model info
        info_file = model_path / "info.txt"
        with open(info_file, 'w') as f:
            f.write(f"Model: {model_name}\n")
            f.write(f"Size: {model_config['size']}\n")  
            f.write(f"Description: {model_config['description']}\n")
            f.write(f"Downloaded: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}\n")
            f.write(f"PyTorch version: {torch.__version__}\n")
        
        logger.info(f"✅ Successfully downloaded and tested {model_key}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to download {model_key}: {e}")
        return False

def create_coreml_model(model_key: str, models_dir: Path):
    """Convert PyTorch model to CoreML for iOS deployment"""
    logger.info(f"Converting {model_key} to CoreML...")
    
    try:
        model_dir = models_dir / model_key / "pytorch_model"
        
        # Load the model
        tokenizer = AutoTokenizer.from_pretrained(model_dir / "tokenizer")
        model = AutoModelForCausalLM.from_pretrained(model_dir / "model")
        model.eval()
        
        # Create sample input
        sample_text = "What is a golf handicap?"
        sample_input = tokenizer(sample_text, return_tensors="pt", max_length=128, padding=True)
        
        # Convert to CoreML
        coreml_model = ct.convert(
            model,
            inputs=[
                ct.TensorType(shape=sample_input['input_ids'].shape, dtype=np.int32, name="input_ids"),
                ct.TensorType(shape=sample_input['attention_mask'].shape, dtype=np.int32, name="attention_mask")
            ],
            outputs=[ct.TensorType(name="logits")],
            compute_units=ct.ComputeUnit.CPU_ONLY
        )
        
        # Save CoreML model
        coreml_path = models_dir / model_key / f"{model_key}_golf_chat.mlpackage"
        coreml_model.save(str(coreml_path))
        
        logger.info(f"✅ CoreML model saved to {coreml_path}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to convert {model_key} to CoreML: {e}")
        return False

def main():
    """Main setup function"""
    logger.info("🏌️ Setting up Golf AI Chatbot Models")
    
    if not check_system_requirements():
        logger.error("System requirements not met")
        return 1
    
    # Create models directory
    models_dir = Path("models/ai_chatbot")
    models_dir.mkdir(parents=True, exist_ok=True)
    
    # Ask user which models to download
    print("\nAvailable models:")
    for key, config in MODELS.items():
        marker = " (RECOMMENDED)" if config.get("recommended") else ""
        print(f"  {key}: {config['size']} - {config['description']}{marker}")
    
    print("\nOptions:")
    print("  1. Download recommended model only (phi-2)")
    print("  2. Download all models") 
    print("  3. Download specific model")
    print("  4. Convert existing model to CoreML")
    
    choice = input("\nEnter choice (1-4): ").strip()
    
    if choice == "1":
        # Download recommended model
        success = download_model("phi-2", models_dir)
        if success:
            logger.info("✅ Setup complete! You can now use the AI golf chatbot.")
        
    elif choice == "2":
        # Download all models
        for model_key in MODELS.keys():
            download_model(model_key, models_dir)
            
    elif choice == "3":
        # Download specific model
        print("\nAvailable models:")
        for i, key in enumerate(MODELS.keys(), 1):
            print(f"  {i}. {key}")
        
        try:
            model_num = int(input("Enter model number: "))
            model_key = list(MODELS.keys())[model_num - 1]
            download_model(model_key, models_dir)
        except (ValueError, IndexError):
            logger.error("Invalid model number")
            
    elif choice == "4":
        # Convert to CoreML
        available_models = [d.name for d in models_dir.iterdir() if d.is_dir()]
        if not available_models:
            logger.error("No models found. Download models first.")
            return 1
            
        print(f"\nAvailable models: {', '.join(available_models)}")
        model_key = input("Enter model name to convert: ").strip()
        
        if model_key in available_models:
            create_coreml_model(model_key, models_dir)
        else:
            logger.error("Model not found")
    
    else:
        logger.error("Invalid choice")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
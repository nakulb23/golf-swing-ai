"""
AI-Powered Golf Chatbot using Local LLM
Uses Microsoft's Phi-2 or similar small model for efficient on-device inference
"""

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
import json
import logging
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import re

logger = logging.getLogger(__name__)

class AIGolfChatbot:
    def __init__(self, model_name: str = "microsoft/phi-2"):
        """
        Initialize the AI Golf Chatbot with a small, efficient language model.
        Default: Microsoft Phi-2 (2.7B parameters) - runs well on CPU/mobile
        Alternative options:
        - "google/flan-t5-base" (250M parameters)
        - "facebook/opt-1.3b" (1.3B parameters)
        - "EleutherAI/pythia-1.4b" (1.4B parameters)
        """
        self.model_name = model_name
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model = None
        self.tokenizer = None
        self.conversation_history = []
        self.max_history = 10  # Keep last 10 exchanges for context
        
        # Golf expertise context
        self.golf_system_prompt = """You are CaddieChat Pro, an expert golf instructor and caddie with decades of experience. You have deep knowledge of:
- Swing mechanics and biomechanics
- Course strategy and management
- Equipment selection and fitting
- Golf rules and etiquette
- Mental game and psychology
- Practice drills and improvement techniques
- Professional tour insights
- Golf history and traditions

Always provide specific, actionable advice. Use appropriate golf terminology but explain complex concepts clearly. Be encouraging but honest about what improvements require. Reference specific techniques, drills, or examples when relevant."""

        # Load model
        self._load_model()
    
    def _load_model(self):
        """Load the language model and tokenizer"""
        try:
            logger.info(f"Loading model: {self.model_name}")
            
            # Load tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.model_name,
                trust_remote_code=True,
                padding_side='left'
            )
            
            # Set pad token if not present
            if self.tokenizer.pad_token is None:
                self.tokenizer.pad_token = self.tokenizer.eos_token
            
            # Load model with optimizations for CPU/mobile
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                device_map="auto" if self.device == "cuda" else None,
                trust_remote_code=True,
                low_cpu_mem_usage=True
            )
            
            if self.device == "cpu":
                # Optimize for CPU inference
                self.model = self.model.to(self.device)
                self.model.eval()
                
                # Use torch.jit.script for faster CPU inference if possible
                try:
                    self.model = torch.jit.script(self.model)
                except:
                    pass  # Not all models support JIT
            
            logger.info(f"Model loaded successfully on {self.device}")
            
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            # Fallback to a simpler model if primary fails
            self._load_fallback_model()
    
    def _load_fallback_model(self):
        """Load a simpler fallback model if primary fails"""
        try:
            self.model_name = "google/flan-t5-base"
            logger.info(f"Loading fallback model: {self.model_name}")
            
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                torch_dtype=torch.float32,
                low_cpu_mem_usage=True
            ).to(self.device)
            
            self.model.eval()
            logger.info("Fallback model loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load fallback model: {e}")
            raise RuntimeError("Unable to load any language model")
    
    def _build_prompt(self, user_message: str) -> str:
        """Build a complete prompt with context and history"""
        
        # Build conversation context
        context = self.golf_system_prompt + "\n\n"
        
        # Add recent conversation history
        if self.conversation_history:
            context += "Recent conversation:\n"
            for exchange in self.conversation_history[-5:]:  # Last 5 exchanges
                context += f"User: {exchange['user']}\n"
                context += f"Assistant: {exchange['assistant']}\n"
            context += "\n"
        
        # Add current question
        prompt = f"{context}User: {user_message}\nAssistant: "
        
        return prompt
    
    def _post_process_response(self, response: str) -> str:
        """Clean up and format the AI response"""
        
        # Remove any repeated text
        lines = response.split('\n')
        seen = set()
        unique_lines = []
        for line in lines:
            if line.strip() and line.strip() not in seen:
                seen.add(line.strip())
                unique_lines.append(line)
        
        response = '\n'.join(unique_lines)
        
        # Ensure response stays on topic
        golf_keywords = ['golf', 'swing', 'club', 'ball', 'shot', 'putt', 'chip', 
                        'drive', 'iron', 'wedge', 'green', 'fairway', 'tee', 
                        'handicap', 'par', 'birdie', 'bogey', 'eagle', 'stroke']
        
        # Check if response is golf-related
        response_lower = response.lower()
        is_golf_related = any(keyword in response_lower for keyword in golf_keywords)
        
        if not is_golf_related and len(response) > 100:
            # Response went off-topic, add golf context back
            response = "Regarding your golf question: " + response
        
        # Limit response length for mobile
        max_length = 500
        if len(response) > max_length:
            # Find a good breaking point
            sentences = response.split('. ')
            truncated = ""
            for sentence in sentences:
                if len(truncated) + len(sentence) < max_length:
                    truncated += sentence + ". "
                else:
                    break
            response = truncated.strip()
        
        return response
    
    def get_response(self, user_message: str) -> Dict[str, any]:
        """
        Generate an AI response to the user's golf question
        
        Args:
            user_message: The user's question or comment
            
        Returns:
            Dict containing the response and metadata
        """
        try:
            # Build the full prompt
            prompt = self._build_prompt(user_message)
            
            # Tokenize input
            inputs = self.tokenizer(
                prompt,
                return_tensors="pt",
                truncation=True,
                max_length=512,
                padding=True
            ).to(self.device)
            
            # Generate response
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=200,
                    min_length=30,
                    temperature=0.7,
                    top_p=0.9,
                    do_sample=True,
                    num_beams=2,
                    early_stopping=True,
                    pad_token_id=self.tokenizer.pad_token_id,
                    eos_token_id=self.tokenizer.eos_token_id
                )
            
            # Decode response
            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            # Extract only the assistant's response
            if "Assistant:" in response:
                response = response.split("Assistant:")[-1].strip()
            elif prompt in response:
                response = response.replace(prompt, "").strip()
            
            # Post-process the response
            response = self._post_process_response(response)
            
            # Add to conversation history
            self.conversation_history.append({
                'user': user_message,
                'assistant': response,
                'timestamp': datetime.now().isoformat()
            })
            
            # Maintain history limit
            if len(self.conversation_history) > self.max_history:
                self.conversation_history = self.conversation_history[-self.max_history:]
            
            # Determine if response is golf-related
            is_golf_related = self._is_golf_related(user_message, response)
            
            return {
                'answer': response,
                'is_golf_related': is_golf_related,
                'confidence': 0.85 if is_golf_related else 0.6,
                'model': self.model_name,
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error generating response: {e}")
            return self._get_fallback_response(user_message)
    
    def _is_golf_related(self, question: str, answer: str) -> bool:
        """Determine if the conversation is golf-related"""
        golf_terms = [
            'golf', 'swing', 'club', 'ball', 'tee', 'green', 'fairway', 
            'putt', 'chip', 'drive', 'iron', 'wedge', 'putter', 'driver',
            'handicap', 'par', 'birdie', 'bogey', 'eagle', 'stroke', 
            'bunker', 'sand', 'rough', 'course', 'hole', 'pin', 'flag',
            'grip', 'stance', 'backswing', 'downswing', 'follow-through',
            'slice', 'hook', 'fade', 'draw', 'shot', 'yardage', 'distance'
        ]
        
        combined = (question + " " + answer).lower()
        return any(term in combined for term in golf_terms)
    
    def _get_fallback_response(self, user_message: str) -> Dict[str, any]:
        """Provide a fallback response if AI generation fails"""
        
        # Simple keyword-based fallback
        message_lower = user_message.lower()
        
        if "handicap" in message_lower:
            response = """A golf handicap is a numerical measure of a golfer's playing ability. It represents the number of strokes above par a player might shoot on average. For example, a 10-handicap typically shoots around 10 strokes over par. Handicaps allow golfers of different skill levels to compete fairly against each other. The USGA handicap system uses your best 8 scores from your last 20 rounds to calculate your handicap index."""
        
        elif "chip" in message_lower:
            response = """A chip shot is a short, low-trajectory shot played near the green. The ball spends minimal time in the air and rolls most of the way to the hole. For a basic chip: use a narrow stance with weight on your front foot, position the ball back of center, keep your hands ahead of the ball, and make a putting-like stroke with minimal wrist action. Club selection depends on how much roll you need - use less loft (7-9 iron) for more roll, more loft (wedge) for less roll."""
        
        elif "slice" in message_lower:
            response = """A slice (ball curving right for right-handed golfers) is usually caused by an open clubface at impact and/or an outside-to-inside swing path. To fix it: strengthen your grip (see 2-3 knuckles on your left hand), ensure your shoulders are square at address, focus on swinging from inside-to-out (feel like you're hitting to right field), and make sure you're rotating through the ball, not sliding. Practice with a headcover just outside your ball - swing without hitting it to promote an inside path."""
        
        else:
            response = """I'm here to help with your golf questions! I can assist with swing mechanics, course strategy, equipment selection, rules, and improvement tips. What specific aspect of golf would you like to know about? Feel free to ask about techniques, common problems like slices or hooks, short game tips, or anything else golf-related."""
        
        return {
            'answer': response,
            'is_golf_related': True,
            'confidence': 0.7,
            'model': 'fallback',
            'timestamp': datetime.now().isoformat()
        }
    
    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []
        logger.info("Conversation history cleared")
    
    def get_conversation_history(self) -> List[Dict]:
        """Get the current conversation history"""
        return self.conversation_history

# Singleton instance for the chatbot
_chatbot_instance = None

def get_chatbot():
    """Get or create the singleton chatbot instance"""
    global _chatbot_instance
    if _chatbot_instance is None:
        _chatbot_instance = AIGolfChatbot()
    return _chatbot_instance
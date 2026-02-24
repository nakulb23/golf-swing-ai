"""
Golf Caddy LLM - Training Dataset Generator

This script creates high-quality golf Q&A pairs for fine-tuning TinyLlama.
Covers: Rules, Swing Mechanics, Equipment, Course Strategy, Mental Game

Usage:
    python golf_dataset_generator.py --output golf_training_data.json --count 2000
"""

import json
import random
from typing import List, Dict
from dataclasses import dataclass
import anthropic  # or use openai
import os

@dataclass
class GolfQA:
    """Golf Question-Answer pair with metadata"""
    question: str
    answer: str
    category: str
    difficulty: str  # beginner, intermediate, advanced
    source: str  # generated, manual, rules

class GolfDatasetGenerator:
    """Generate comprehensive golf training data"""

    def __init__(self, api_key: str = None):
        # Use Claude API for generating high-quality golf Q&A
        self.client = anthropic.Anthropic(api_key=api_key or os.getenv('ANTHROPIC_API_KEY'))
        self.categories = [
            'rules', 'swing_mechanics', 'equipment', 'course_strategy',
            'putting', 'short_game', 'mental_game', 'practice', 'etiquette',
            'ball_flight_laws', 'club_fitting', 'course_conditions'
        ]

    def generate_seed_data(self) -> List[GolfQA]:
        """Manual high-quality examples from your fallback responses"""
        return [
            GolfQA(
                question="Where should I place the ball if it lands on cart path?",
                answer="""When your ball lands on a cart path, you get free relief under Rule 16.1 (Abnormal Course Conditions):

• Identify your nearest point of complete relief (where the cart path doesn't interfere with your stance or swing)
• Drop within one club-length of that point, no closer to the hole
• Must be in the same area of the course (fairway, rough, etc.)
• No penalty strokes

If the cart path doesn't interfere with your swing or stance, you can play it as it lies. Remember to protect your clubs when hitting off hard surfaces!""",
                category="rules",
                difficulty="beginner",
                source="manual"
            ),
            GolfQA(
                question="How do I fix my slice?",
                answer="""A slice is usually caused by an open clubface at impact combined with an outside-in swing path. Here's how to fix it:

• Strengthen your grip (see 2-3 knuckles on your left hand)
• Check your setup: align shoulders parallel to target line
• Feel like you're swinging toward right field (for right-handers)
• Focus on rotating your forearms through impact
• Practice with alignment sticks to groove an inside-out path

Try the "gate drill": Place two alignment sticks creating a gate just past the ball. This encourages the proper inside-out path.""",
                category="swing_mechanics",
                difficulty="intermediate",
                source="manual"
            ),
            GolfQA(
                question="What are standard wedge lofts?",
                answer="""Standard wedge lofts:

• Pitching Wedge (PW): 44-48°
• Gap Wedge (GW/AW): 50-52°
• Sand Wedge (SW): 54-56°
• Lob Wedge (LW): 58-60°

Most golfers carry 3-4 wedges with 4-6° gaps between them. For example: PW (46°), GW (50°), SW (54°), LW (58°). The right setup depends on your iron lofts and distance gaps.

Pro tip: Focus on bounce angle too! Higher bounce (10-14°) for soft conditions, lower bounce (4-8°) for firm turf.""",
                category="equipment",
                difficulty="beginner",
                source="manual"
            ),
            # Add more seed examples...
        ]

    def generate_rules_questions(self, count: int = 300) -> List[GolfQA]:
        """Generate USGA rules questions using Claude"""
        prompt = f"""Generate {count} golf rules questions and answers. Cover:
- Ball in hazards (water, bunkers, penalty areas)
- Unplayable lies and relief procedures
- Equipment rules
- Match play vs stroke play
- Local rules
- Out of bounds and lost ball
- Embedded ball, ground under repair
- Provisional balls

Format each as:
Q: [specific scenario question]
A: [detailed answer with rule number, procedure, penalties]

Make answers authoritative, accurate, and helpful. Include rule numbers (e.g., Rule 16.1)."""

        return self._generate_with_claude(prompt, "rules", count)

    def generate_swing_mechanics_questions(self, count: int = 400) -> List[GolfQA]:
        """Generate swing technique questions"""
        prompt = f"""Generate {count} golf swing mechanics questions covering:
- Setup and posture
- Grip variations
- Backswing mechanics
- Downswing sequence
- Impact position
- Follow-through
- Common swing faults (slice, hook, topped shots, fat shots, thin shots)
- Ball flight laws
- Swing plane
- Weight transfer

Mix beginner, intermediate, and advanced levels.
Include specific drills and fixes.

Format:
Q: [specific swing issue or question]
A: [clear explanation with fixes and drills]"""

        return self._generate_with_claude(prompt, "swing_mechanics", count)

    def generate_equipment_questions(self, count: int = 200) -> List[GolfQA]:
        """Generate equipment and club fitting questions"""
        prompt = f"""Generate {count} golf equipment questions about:
- Driver specs (loft, shaft flex)
- Iron selection and distances
- Wedge setup and gapping
- Putter fitting
- Ball selection
- Shaft flex and weight
- Club fitting basics
- When to upgrade equipment
- Club specifications for different swing speeds

Be specific with numbers and recommendations.

Format:
Q: [equipment question]
A: [detailed answer with specs and recommendations]"""

        return self._generate_with_claude(prompt, "equipment", count)

    def generate_course_strategy_questions(self, count: int = 300) -> List[GolfQA]:
        """Generate course management and strategy questions"""
        prompt = f"""Generate {count} golf course strategy questions about:
- Tee shot strategy
- Approach shot selection
- When to play safe vs aggressive
- Wind adjustments
- Uphill/downhill lies
- Hazard management
- Pin position strategy
- Scoring zones
- Percentage golf
- Shot shape for different holes

Include decision-making frameworks.

Format:
Q: [strategy scenario]
A: [strategic advice with reasoning]"""

        return self._generate_with_claude(prompt, "course_strategy", count)

    def generate_short_game_questions(self, count: int = 300) -> List[GolfQA]:
        """Generate putting, chipping, pitching questions"""
        prompt = f"""Generate {count} short game questions about:
- Putting fundamentals
- Reading greens
- Distance control putting
- Chipping technique
- Pitch shot execution
- Bump and run
- Flop shots
- Bunker play
- Various lies around green
- Short game practice drills

Format:
Q: [short game question]
A: [technique explanation with drills]"""

        return self._generate_with_claude(prompt, "short_game", count)

    def generate_mental_game_questions(self, count: int = 200) -> List[GolfQA]:
        """Generate mental game and practice questions"""
        prompt = f"""Generate {count} questions about:
- Pre-shot routine
- Managing pressure
- Course management mindset
- Practice strategies
- Dealing with bad shots
- Visualization techniques
- Focus and concentration
- Tournament preparation
- Mental reset between holes

Format:
Q: [mental game question]
A: [psychological advice and techniques]"""

        return self._generate_with_claude(prompt, "mental_game", count)

    def generate_practice_drills(self, count: int = 200) -> List[GolfQA]:
        """Generate practice drill questions"""
        prompt = f"""Generate {count} golf practice questions about:
- Driving range practice routines
- Practice drills for specific skills
- How to structure practice time
- Short game practice games
- Putting drills
- Pre-round warmup
- Home practice drills
- Practice with purpose

Format:
Q: [practice question]
A: [specific drill or practice routine]"""

        return self._generate_with_claude(prompt, "practice", count)

    def _generate_with_claude(self, prompt: str, category: str, count: int) -> List[GolfQA]:
        """Use Claude to generate Q&A pairs"""
        try:
            message = self.client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=4000,
                temperature=0.8,  # Some variety
                messages=[{
                    "role": "user",
                    "content": f"""{prompt}

IMPORTANT:
- Answers must be accurate and authoritative
- Include specific numbers, rule references, and drills
- Use bullet points for clarity
- Be concise but comprehensive (2-4 sentences or bullet lists)
- Mix difficulty levels

Generate exactly {count} unique Q&A pairs."""
                }]
            )

            # Parse Claude's response into GolfQA objects
            qa_pairs = self._parse_claude_response(message.content[0].text, category)
            print(f"✅ Generated {len(qa_pairs)} {category} Q&A pairs")
            return qa_pairs

        except Exception as e:
            print(f"❌ Error generating {category}: {e}")
            return []

    def _parse_claude_response(self, response: str, category: str) -> List[GolfQA]:
        """Parse Claude's response into structured Q&A"""
        qa_pairs = []
        lines = response.strip().split('\n')

        current_q = None
        current_a = []

        for line in lines:
            line = line.strip()
            if line.startswith('Q:'):
                # Save previous Q&A if exists
                if current_q and current_a:
                    qa_pairs.append(GolfQA(
                        question=current_q,
                        answer='\n'.join(current_a).strip(),
                        category=category,
                        difficulty=self._infer_difficulty('\n'.join(current_a)),
                        source='generated'
                    ))

                # Start new Q&A
                current_q = line[2:].strip()
                current_a = []

            elif line.startswith('A:'):
                current_a.append(line[2:].strip())

            elif line and current_q:  # Continuation of answer
                current_a.append(line)

        # Save last Q&A
        if current_q and current_a:
            qa_pairs.append(GolfQA(
                question=current_q,
                answer='\n'.join(current_a).strip(),
                category=category,
                difficulty=self._infer_difficulty('\n'.join(current_a)),
                source='generated'
            ))

        return qa_pairs

    def _infer_difficulty(self, answer: str) -> str:
        """Infer difficulty level from answer complexity"""
        if any(word in answer.lower() for word in ['advanced', 'professional', 'tour', 'sophisticated']):
            return 'advanced'
        elif any(word in answer.lower() for word in ['intermediate', 'experienced', 'consistent']):
            return 'intermediate'
        else:
            return 'beginner'

    def generate_full_dataset(self, total_count: int = 2000) -> List[GolfQA]:
        """Generate complete training dataset"""
        print(f"🏌️ Generating {total_count} golf Q&A pairs...")

        dataset = []

        # Start with seed data (your fallback responses)
        print("📝 Adding seed data...")
        dataset.extend(self.generate_seed_data())

        # Generate by category (proportional distribution)
        print("🤖 Generating with Claude API...")
        dataset.extend(self.generate_rules_questions(300))
        dataset.extend(self.generate_swing_mechanics_questions(400))
        dataset.extend(self.generate_equipment_questions(200))
        dataset.extend(self.generate_course_strategy_questions(300))
        dataset.extend(self.generate_short_game_questions(300))
        dataset.extend(self.generate_mental_game_questions(200))
        dataset.extend(self.generate_practice_drills(200))

        # Shuffle to mix categories
        random.shuffle(dataset)

        print(f"✅ Generated {len(dataset)} total Q&A pairs")
        return dataset[:total_count]

    def export_to_json(self, dataset: List[GolfQA], output_file: str):
        """Export to JSON for fine-tuning"""
        data = [{
            'question': qa.question,
            'answer': qa.answer,
            'category': qa.category,
            'difficulty': qa.difficulty,
            'source': qa.source
        } for qa in dataset]

        with open(output_file, 'w') as f:
            json.dump(data, f, indent=2)

        print(f"💾 Saved {len(data)} Q&A pairs to {output_file}")

    def export_for_training(self, dataset: List[GolfQA], output_file: str):
        """Export in format for TinyLlama fine-tuning (Alpaca format)"""
        training_data = []

        for qa in dataset:
            # Alpaca instruction format
            training_data.append({
                'instruction': 'You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately and helpfully.',
                'input': qa.question,
                'output': qa.answer,
                'category': qa.category
            })

        with open(output_file, 'w') as f:
            json.dump(training_data, f, indent=2)

        print(f"💾 Saved training data to {output_file}")

        # Print statistics
        print("\n📊 Dataset Statistics:")
        print(f"Total examples: {len(training_data)}")

        categories = {}
        for qa in dataset:
            categories[qa.category] = categories.get(qa.category, 0) + 1

        for cat, count in sorted(categories.items()):
            print(f"  {cat}: {count}")

def main():
    """Main execution"""
    import argparse

    parser = argparse.ArgumentParser(description='Generate Golf Caddy training dataset')
    parser.add_argument('--output', default='golf_training_data.json', help='Output file')
    parser.add_argument('--count', type=int, default=2000, help='Number of Q&A pairs')
    parser.add_argument('--api-key', help='Anthropic API key (or set ANTHROPIC_API_KEY env var)')

    args = parser.parse_args()

    # Initialize generator
    generator = GolfDatasetGenerator(api_key=args.api_key)

    # Generate dataset
    dataset = generator.generate_full_dataset(total_count=args.count)

    # Export both formats
    generator.export_to_json(dataset, args.output)
    generator.export_for_training(dataset, args.output.replace('.json', '_training.json'))

    print("\n✅ Dataset generation complete!")
    print(f"Next step: Run fine-tuning script with {args.output.replace('.json', '_training.json')}")

if __name__ == '__main__':
    main()

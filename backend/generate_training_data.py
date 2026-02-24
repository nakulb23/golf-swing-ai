#!/usr/bin/env python3
"""
Generate comprehensive golf training dataset for GolfCaddy-1B

This creates 2000+ high-quality golf Q&A pairs in Alpaca format for fine-tuning.
"""

import json
import os
from typing import List, Dict

def create_base_training_data() -> List[Dict]:
    """Create foundational golf Q&A from expert knowledge"""

    data = []

    # RULES - Cart Path & Relief
    data.extend([
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "Where should I place the ball if it lands on cart path?",
            "output": "When your ball lands on a cart path, you get **free relief under Rule 16.1** (Abnormal Course Conditions):\n\n**Procedure**:\n• Find your nearest point of complete relief (where the path doesn't interfere)\n• Drop within one club-length, no closer to the hole\n• Must stay in the same area (fairway, rough, etc.)\n• **No penalty strokes**\n\nIf the path doesn't interfere with your stance or swing, you can play it as it lies. Remember to protect your clubs when hitting off hard surfaces!"
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "Can I get relief from a cart path?",
            "output": "Yes! Cart paths are **abnormal course conditions** under Rule 16.1. You get free relief (no penalty) if the path interferes with your stance, swing, or ball position. Drop within one club-length of your nearest point of complete relief, no closer to the hole, in the same area of the course."
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What if the cart path is in my way but my ball isn't on it?",
            "output": "If the cart path interferes with your **stance or swing area** (even if your ball isn't on it), you still get free relief under Rule 16.1. Find the nearest point where the path doesn't interfere, and drop within one club-length."
        },

        # RULES - Water Hazards
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "My ball went in a water hazard with yellow stakes. What are my options?",
            "output": "Yellow stakes = **penalty area**. You have these options (1 penalty stroke):\n\n1. **Stroke and distance**: Re-hit from where you last played\n2. **Back-on-line relief**: Drop anywhere on a line from the hole through where ball entered, going back as far as you want\n\nTake relief from where the ball **last crossed** the margin, not where it ended up in the water."
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What's the difference between red and yellow penalty areas?",
            "output": "**Yellow stakes** (penalty area): Stroke & distance OR back-on-line relief\n\n**Red stakes** (lateral penalty area): Same options PLUS you can drop within 2 club-lengths of where ball entered, no closer to hole\n\nBoth are 1 penalty stroke. Red stakes give you an extra lateral relief option, which is usually more favorable."
        },

        # RULES - Out of Bounds
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "My ball might be out of bounds. What should I do?",
            "output": "Hit a **provisional ball** immediately! Announce \"I'm hitting a provisional\" before playing it.\n\n**If original is OB**: Continue with provisional (+1 penalty)\n**If original is found in bounds**: Pick up provisional (no penalty)\n\nThis saves you from walking back if it's OB. You have 3 minutes to search for the original."
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What's the penalty for out of bounds?",
            "output": "**Stroke and distance** - return to where you last played and re-hit with a 1 stroke penalty. So if your drive goes OB, you're hitting your 3rd shot from the tee (1st drive + 1 penalty + re-hit = 3).\n\nSome courses use a local rule allowing you to drop near where it went OB for 2 strokes, but this isn't standard."
        },

        # SWING - Slice
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "How do I fix my slice?",
            "output": "A slice comes from an **open clubface** at impact + **outside-in path**. Here's the fix:\n\n**Grip**: Strengthen it - see 2-3 knuckles on your left hand (right-hander)\n**Alignment**: Shoulders parallel to target, not aimed left\n**Path**: Feel like swinging toward right field\n**Release**: Rotate forearms through impact\n**Drill**: Gate drill with alignment sticks\n\nMost slicers have a grip that's too weak - fix that first!"
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "Why do I slice my driver but not my irons?",
            "output": "Driver slicing is common because:\n\n• **Lower loft** amplifies sidespin (slice spin)\n• **Longer shaft** harder to square the face\n• **Ball position** - too far forward can open face\n• **Tee height** - teeing too high encourages upward, glancing blow\n\nIrons have more loft which reduces sidespin. Try: shorter tee, ball slightly back in stance, and really focus on squaring the face at impact."
        },

        # SWING - Hook
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "I keep hooking the ball. What's causing it?",
            "output": "A hook = **closed clubface** + **inside-out path**. Common causes:\n\n• **Grip too strong**: Seeing too many knuckles\n• **Ball too far back**: Promotes closed face\n• **Overactive hands**: Rolling wrists too early\n• **Closed shoulders**: Aimed too far right at setup\n\n**Fix**: Weaken grip slightly, check ball position, feel like you're holding the face open through impact."
        },

        # SWING - Topped Shots
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "Why do I keep topping the ball?",
            "output": "Topping happens when you **rise up** through impact or **swing too steeply down**. Fixes:\n\n• **Stay down**: Keep chest over ball, maintain spine angle\n• **Finish your swing**: Don't try to \"help\" ball up\n• **Weight forward**: 60% on lead foot through impact\n• **Trust the loft**: Club lifts ball, not you\n\n**Drill**: Place tee 6\" past ball, try to brush it after impact."
        },

        # EQUIPMENT - Wedges
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What wedge lofts should I carry?",
            "output": "Standard setup with 4-6° gaps:\n\n• **PW**: 44-48°\n• **GW**: 50-52°\n• **SW**: 54-56°\n• **LW**: 58-60°\n\n**Example**: PW (46°), GW (50°), SW (54°), LW (58°)\n\n**Bounce**: High (10-14°) for soft turf/bunkers, Low (4-8°) for firm conditions. Most golfers need 3-4 wedges total."
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What bounce should I get on my sand wedge?",
            "output": "**Bounce selection** depends on:\n\n**High bounce (12-14°)**:\n• Soft sand, fluffy lies\n• Sweeping swing (shallow attack)\n• Bunkers with soft sand\n\n**Low bounce (8-10°)**:\n• Firm turf, tight lies\n• Steep swing (descending blow)\n• Hard sand conditions\n\n**Medium (10-12°)**: Most versatile. If unsure, go with 10-12° on your SW for all-around performance."
        },

        # EQUIPMENT - Driver
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What driver loft should I use?",
            "output": "Driver loft depends on **swing speed**:\n\n• **<85 mph**: 12-14° (more loft = easier launch)\n• **85-95 mph**: 10.5-12° (most common)\n• **>95 mph**: 8.5-10.5° (faster speeds need less loft)\n\n**Higher loft** = easier to launch + more forgiving. Don't chase low loft for \"distance\" - proper launch angle matters more! Get fitted to optimize your launch conditions."
        },

        # STRATEGY
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "Should I always aim for the pin?",
            "output": "**No!** Smart course management means:\n\n• Aim for **center of green** (biggest target)\n• Only attack pins when:\n  - You have the right yardage\n  - Miss won't be penalized\n  - You're playing well\n\n**Fat part of green** > Tucked pin with trouble. A 20-footer beats being in a bunker or water. Play percentage golf - it's how pros shoot low scores."
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "How do I play in the wind?",
            "output": "**Into wind**:\n• Take 1-3 more clubs\n• Ball back in stance, lower trajectory\n• Swing easier (80% power)\n• \"When it's breezy, swing easy\"\n\n**Downwind**:\n• Take 1-2 less clubs\n• Higher trajectory, land short\n• Let wind carry it\n\n**Crosswind**:\n• Aim into wind, let it drift\n• OR ride the wind (advanced)\n\nKey: Swing smooth in wind!"
        },

        # SHORT GAME - Putting
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "How do I improve my putting?",
            "output": "**Putting fundamentals**:\n\n**Setup**:\n• Eyes over ball (or just inside)\n• Light grip pressure (3/10)\n• Shoulders square to line\n\n**Stroke**:\n• Pendulum from shoulders, not hands\n• Accelerate through impact\n• No deceleration\n\n**Practice**: Focus on **distance control** over line. 3-putt prevention > making everything. Drill: Ladder (putts to 10', 20', 30')."
        },
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "How do I read greens better?",
            "output": "**Green reading**:\n\n1. **Overall slope**: Look from low point - where does water drain?\n2. **Grain**: Shiny = downhill, dull = uphill (warm climates)\n3. **High point**: Putts break away from high side\n4. **Speed > Line**: Right speed lets ball \"find\" hole\n\n**Pro tip**: Read while walking up to green. Trust first instinct - don't over-analyze!"
        },

        # SHORT GAME - Chipping
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "What's the best chipping technique?",
            "output": "**Chipping fundamentals**:\n\n**Setup**:\n• Narrow stance, weight forward (60-70%)\n• Hands ahead of ball\n• Ball back in stance\n\n**Technique**:\n• Use putting grip for control\n• Quiet hands, shoulders drive motion\n• Bump and run > High flop\n\n**Club selection**: More green = less loft (8i), Less green = more loft (SW)\n\n**Rule**: Get ball on green and rolling ASAP!"
        },

        # MENTAL GAME
        {
            "instruction": "You are CaddieChat Pro, an expert golf caddie. Answer the following golf question accurately.",
            "input": "How do I deal with pressure on the golf course?",
            "output": "**Mental game under pressure**:\n\n**Pre-shot routine**:\n1. Stand behind ball, visualize shot\n2. Pick specific target\n3. Practice swing with feel\n4. Address, look at target once\n5. TRUST and swing\n\n**Pressure management**:\n• Deep breaths before shots\n• Focus on process, not score\n• Accept bad shots happen\n• Play one shot at a time\n\n**Reset**: Bad hole? Forget it. Even pros make bogeys!"
        },
    ])

    return data

def save_training_data(data: List[Dict], output_file: str):
    """Save to JSON for fine-tuning"""
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)

    print(f"✅ Saved {len(data)} training examples to {output_file}")
    print(f"📊 File size: {os.path.getsize(output_file) / 1024:.1f} KB")

    # Print sample
    print("\n📝 Sample training example:")
    print(json.dumps(data[0], indent=2))

def main():
    print("🏌️ Generating GolfCaddy-1B training dataset...\n")

    # Create base data
    training_data = create_base_training_data()

    # Save
    output_file = "golfcaddy_training_base.json"
    save_training_data(training_data, output_file)

    print(f"\n📦 Next steps:")
    print(f"1. Review {output_file}")
    print(f"2. Run golf_dataset_generator.py to expand to 2000+ examples")
    print(f"3. Upload to Google Colab and start training!")

if __name__ == "__main__":
    main()

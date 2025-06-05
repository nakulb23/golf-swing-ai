#!/usr/bin/env python3
"""
Golf Q&A Chatbot - Golf-only question answering system
Includes PGA major tournament data and general golf knowledge
"""

import json
import re
from datetime import datetime
from typing import Dict, List, Optional

class CaddieChat:
    """CaddieChat - Golf-focused chatbot with tournament data and swing analysis knowledge"""
    
    def __init__(self):
        self.pga_major_winners = self._load_pga_data()
        self.golf_knowledge = self._load_golf_knowledge()
        
    def _load_pga_data(self) -> Dict:
        """Load PGA major tournament winners data (2014-2024)"""
        return {
            "masters": {
                2024: {"winner": "Scottie Scheffler", "score": "-11", "location": "Augusta National"},
                2023: {"winner": "Jon Rahm", "score": "-12", "location": "Augusta National"},
                2022: {"winner": "Scottie Scheffler", "score": "-10", "location": "Augusta National"},
                2021: {"winner": "Hideki Matsuyama", "score": "-10", "location": "Augusta National"},
                2020: {"winner": "Dustin Johnson", "score": "-20", "location": "Augusta National"},
                2019: {"winner": "Tiger Woods", "score": "-13", "location": "Augusta National"},
                2018: {"winner": "Patrick Reed", "score": "-15", "location": "Augusta National"},
                2017: {"winner": "Sergio Garcia", "score": "-9", "location": "Augusta National"},
                2016: {"winner": "Danny Willett", "score": "-5", "location": "Augusta National"},
                2015: {"winner": "Jordan Spieth", "score": "-18", "location": "Augusta National"},
                2014: {"winner": "Bubba Watson", "score": "-8", "location": "Augusta National"}
            },
            "us_open": {
                2024: {"winner": "Bryson DeChambeau", "score": "-6", "location": "Pinehurst No. 2"},
                2023: {"winner": "Wyndham Clark", "score": "-10", "location": "Los Angeles Country Club"},
                2022: {"winner": "Matt Fitzpatrick", "score": "-6", "location": "The Country Club"},
                2021: {"winner": "Jon Rahm", "score": "-6", "location": "Torrey Pines"},
                2020: {"winner": "Bryson DeChambeau", "score": "-6", "location": "Winged Foot"},
                2019: {"winner": "Gary Woodland", "score": "-13", "location": "Pebble Beach"},
                2018: {"winner": "Brooks Koepka", "score": "+1", "location": "Shinnecock Hills"},
                2017: {"winner": "Brooks Koepka", "score": "-16", "location": "Erin Hills"},
                2016: {"winner": "Dustin Johnson", "score": "-4", "location": "Oakmont"},
                2015: {"winner": "Jordan Spieth", "score": "-5", "location": "Chambers Bay"},
                2014: {"winner": "Martin Kaymer", "score": "-9", "location": "Pinehurst No. 2"}
            },
            "british_open": {
                2024: {"winner": "Xander Schauffele", "score": "-9", "location": "Royal Troon"},
                2023: {"winner": "Brian Harman", "score": "-13", "location": "Royal Liverpool"},
                2022: {"winner": "Cameron Smith", "score": "-20", "location": "St. Andrews"},
                2021: {"winner": "Collin Morikawa", "score": "-15", "location": "Royal St. George's"},
                2020: {"winner": "Cancelled (COVID-19)", "score": "N/A", "location": "N/A"},
                2019: {"winner": "Shane Lowry", "score": "-15", "location": "Royal Portrush"},
                2018: {"winner": "Francesco Molinari", "score": "-8", "location": "Carnoustie"},
                2017: {"winner": "Jordan Spieth", "score": "-12", "location": "Royal Birkdale"},
                2016: {"winner": "Henrik Stenson", "score": "-20", "location": "Royal Troon"},
                2015: {"winner": "Zach Johnson", "score": "-15", "location": "St. Andrews"},
                2014: {"winner": "Rory McIlroy", "score": "-17", "location": "Royal Liverpool"}
            },
            "pga_championship": {
                2024: {"winner": "Xander Schauffele", "score": "-21", "location": "Valhalla"},
                2023: {"winner": "Brooks Koepka", "score": "-19", "location": "Oak Hill"},
                2022: {"winner": "Justin Thomas", "score": "-5", "location": "Southern Hills"},
                2021: {"winner": "Phil Mickelson", "score": "-6", "location": "Kiawah Island"},
                2020: {"winner": "Collin Morikawa", "score": "-13", "location": "Harding Park"},
                2019: {"winner": "Brooks Koepka", "score": "-8", "location": "Bethpage Black"},
                2018: {"winner": "Brooks Koepka", "score": "-16", "location": "Bellerive"},
                2017: {"winner": "Justin Thomas", "score": "-8", "location": "Quail Hollow"},
                2016: {"winner": "Jimmy Walker", "score": "-14", "location": "Baltusrol"},
                2015: {"winner": "Jason Day", "score": "-20", "location": "Whistling Straits"},
                2014: {"winner": "Rory McIlroy", "score": "-16", "location": "Valhalla"}
            }
        }
    
    def _load_golf_knowledge(self) -> Dict:
        """Load general golf knowledge base"""
        return {
            "swing_basics": {
                "grip": "The foundation of a good golf swing. Use a neutral grip with hands working together.",
                "stance": "Feet should be shoulder-width apart with slight knee flex and straight back.",
                "backswing": "Turn shoulders 90 degrees while keeping left arm straight (for right-handed golfers).",
                "downswing": "Start with hips, then shoulders, creating lag with the club.",
                "follow_through": "Complete the swing with balanced finish, weight on front foot."
            },
            "swing_plane": {
                "on_plane": "Swing plane between 35-55 degrees from vertical. Ideal for most golfers.",
                "too_flat": "Swing plane less than 35 degrees. Can cause hooks and inconsistent contact.",
                "too_steep": "Swing plane more than 55 degrees. Often leads to slices and fat shots."
            },
            "equipment": {
                "driver": "Longest club, 8.5-12 degree loft, used for tee shots on par 4s and 5s.",
                "irons": "Numbered 3-9, progressive lofts for different distances and trajectories.",
                "wedges": "Pitching, gap, sand, lob wedges for short game and trouble shots.",
                "putter": "Flat-faced club for rolling the ball on the green."
            },
            "rules": {
                "stroke_play": "Count every stroke. Lowest total score wins.",
                "match_play": "Win individual holes. Player who wins most holes wins the match.",
                "out_of_bounds": "White stakes or lines. Penalty stroke and distance.",
                "water_hazard": "Yellow or red stakes. Options for relief with penalty."
            }
        }
    
    def is_golf_question(self, question: str) -> bool:
        """Check if the question is golf-related"""
        golf_keywords = [
            "golf", "swing", "club", "ball", "green", "tee", "fairway", "rough",
            "bunker", "sand", "water", "hazard", "par", "birdie", "eagle", "bogey",
            "driver", "iron", "wedge", "putter", "masters", "pga", "tournament",
            "major", "championship", "tiger", "woods", "stroke", "handicap",
            "course", "hole", "pin", "flag", "caddie", "grip", "stance", "backswing",
            "downswing", "follow through", "slice", "hook", "fade", "draw",
            "chip", "pitch", "putt", "approach", "yardage", "loft", "lie"
        ]
        
        question_lower = question.lower()
        return any(keyword in question_lower for keyword in golf_keywords)
    
    def answer_question(self, question: str) -> str:
        """Answer golf-related questions"""
        
        if not self.is_golf_question(question):
            return "I can only answer golf-related questions. Please ask me about golf swings, tournaments, rules, equipment, or techniques!"
        
        question_lower = question.lower()
        
        # Tournament/winner queries
        if any(word in question_lower for word in ["winner", "won", "champion", "masters", "us open", "british open", "pga championship"]):
            return self._answer_tournament_question(question_lower)
        
        # Swing technique queries
        if any(word in question_lower for word in ["swing", "plane", "grip", "stance", "backswing", "downswing"]):
            return self._answer_swing_question(question_lower)
        
        # Equipment queries
        if any(word in question_lower for word in ["club", "driver", "iron", "wedge", "putter", "equipment"]):
            return self._answer_equipment_question(question_lower)
        
        # Rules queries
        if any(word in question_lower for word in ["rule", "penalty", "relief", "out of bounds", "water hazard"]):
            return self._answer_rules_question(question_lower)
        
        # General golf knowledge
        return self._general_golf_response(question_lower)
    
    def _answer_tournament_question(self, question: str) -> str:
        """Answer tournament-related questions"""
        
        # Extract year if mentioned
        year_match = re.search(r'\b(20\d{2})\b', question)
        year = int(year_match.group(1)) if year_match else 2024
        
        if "masters" in question:
            if year in self.pga_major_winners["masters"]:
                data = self.pga_major_winners["masters"][year]
                return f"The {year} Masters winner was {data['winner']} with a score of {data['score']} at {data['location']}."
            else:
                return f"I don't have Masters data for {year}. I have data from 2014-2024."
        
        elif "us open" in question:
            if year in self.pga_major_winners["us_open"]:
                data = self.pga_major_winners["us_open"][year]
                return f"The {year} US Open winner was {data['winner']} with a score of {data['score']} at {data['location']}."
            else:
                return f"I don't have US Open data for {year}. I have data from 2014-2024."
        
        elif "british open" in question or "open championship" in question:
            if year in self.pga_major_winners["british_open"]:
                data = self.pga_major_winners["british_open"][year]
                return f"The {year} British Open winner was {data['winner']} with a score of {data['score']} at {data['location']}."
            else:
                return f"I don't have British Open data for {year}. I have data from 2014-2024."
        
        elif "pga championship" in question:
            if year in self.pga_major_winners["pga_championship"]:
                data = self.pga_major_winners["pga_championship"][year]
                return f"The {year} PGA Championship winner was {data['winner']} with a score of {data['score']} at {data['location']}."
            else:
                return f"I don't have PGA Championship data for {year}. I have data from 2014-2024."
        
        # Multiple majors or general tournament question
        return self._get_major_summary(year)
    
    def _get_major_summary(self, year: int) -> str:
        """Get summary of all majors for a year"""
        if year not in range(2014, 2025):
            return f"I have major championship data from 2014-2024. Please ask about a year in that range."
        
        summary = f"**{year} Major Championship Winners:**\n"
        
        if year in self.pga_major_winners["masters"]:
            masters = self.pga_major_winners["masters"][year]
            summary += f"• Masters: {masters['winner']} ({masters['score']})\n"
        
        if year in self.pga_major_winners["pga_championship"]:
            pga = self.pga_major_winners["pga_championship"][year]
            summary += f"• PGA Championship: {pga['winner']} ({pga['score']})\n"
        
        if year in self.pga_major_winners["us_open"]:
            us_open = self.pga_major_winners["us_open"][year]
            summary += f"• US Open: {us_open['winner']} ({us_open['score']})\n"
        
        if year in self.pga_major_winners["british_open"]:
            british = self.pga_major_winners["british_open"][year]
            summary += f"• British Open: {british['winner']} ({british['score']})\n"
        
        return summary
    
    def _answer_swing_question(self, question: str) -> str:
        """Answer swing technique questions"""
        
        if "plane" in question:
            if "flat" in question:
                return self.golf_knowledge["swing_plane"]["too_flat"]
            elif "steep" in question:
                return self.golf_knowledge["swing_plane"]["too_steep"]
            else:
                return self.golf_knowledge["swing_plane"]["on_plane"]
        
        elif "grip" in question:
            return self.golf_knowledge["swing_basics"]["grip"]
        elif "stance" in question:
            return self.golf_knowledge["swing_basics"]["stance"]
        elif "backswing" in question:
            return self.golf_knowledge["swing_basics"]["backswing"]
        elif "downswing" in question:
            return self.golf_knowledge["swing_basics"]["downswing"]
        elif "follow through" in question:
            return self.golf_knowledge["swing_basics"]["follow_through"]
        
        return "Golf swing fundamentals include proper grip, stance, backswing, downswing, and follow-through. Ask me about any specific aspect!"
    
    def _answer_equipment_question(self, question: str) -> str:
        """Answer equipment-related questions"""
        
        if "driver" in question:
            return self.golf_knowledge["equipment"]["driver"]
        elif "iron" in question:
            return self.golf_knowledge["equipment"]["irons"]
        elif "wedge" in question:
            return self.golf_knowledge["equipment"]["wedges"]
        elif "putter" in question:
            return self.golf_knowledge["equipment"]["putter"]
        
        return "Golf equipment includes drivers, irons, wedges, and putters. Each club has specific purposes and characteristics. What would you like to know?"
    
    def _answer_rules_question(self, question: str) -> str:
        """Answer rules-related questions"""
        
        if "stroke play" in question:
            return self.golf_knowledge["rules"]["stroke_play"]
        elif "match play" in question:
            return self.golf_knowledge["rules"]["match_play"]
        elif "out of bounds" in question:
            return self.golf_knowledge["rules"]["out_of_bounds"]
        elif "water" in question or "hazard" in question:
            return self.golf_knowledge["rules"]["water_hazard"]
        
        return "Golf rules cover stroke play, match play, penalties, and relief procedures. What specific rule would you like to know about?"
    
    def _general_golf_response(self, question: str) -> str:
        """General golf response for unmatched questions"""
        return ("I'm here to help with golf questions! I can tell you about:\n"
                "• PGA major tournament winners (2014-2024)\n"
                "• Swing techniques and mechanics\n"
                "• Golf equipment and clubs\n"
                "• Rules and penalties\n"
                "• Course strategy and tips\n\n"
                "What would you like to know?")

def main():
    """Test CaddieChat"""
    chatbot = CaddieChat()
    
    # Test questions
    test_questions = [
        "Who won the 2024 Masters?",
        "What is the proper golf grip?",
        "Tell me about swing plane",
        "Who won all the majors in 2019?",
        "What's the weather like?",  # Non-golf question
        "How do I fix a slice?",
        "What clubs should I use for approach shots?"
    ]
    
    print("🏌️ CaddieChat Test\n" + "="*50)
    
    for question in test_questions:
        print(f"\nQ: {question}")
        answer = chatbot.answer_question(question)
        print(f"A: {answer}")

if __name__ == "__main__":
    main()
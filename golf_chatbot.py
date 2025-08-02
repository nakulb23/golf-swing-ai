#!/usr/bin/env python3
"""
Enhanced CaddieChat - Conversational Golf AI Assistant
Provides comprehensive golf guidance, club selection, course strategy, and tournament knowledge
"""

import json
import re
from datetime import datetime
from typing import Dict, List, Optional, Any

class CaddieChat:
    """Enhanced CaddieChat - Conversational golf AI with memory and detailed guidance"""
    
    def __init__(self):
        self.pga_major_winners = self._load_pga_data()
        self.golf_knowledge = self._load_golf_knowledge()
        self.conversation_history = []
        self.user_context = {
            "handicap": None,
            "preferred_clubs": [],
            "course_conditions": None,
            "swing_tendencies": [],
            "last_topic": None
        }
        
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
        """Load comprehensive golf knowledge base with detailed guidance"""
        return {
            "swing_basics": {
                "grip": "The foundation of a good golf swing. Use a neutral grip with hands working together. Your lead hand should show 2-3 knuckles when looking down.",
                "stance": "Feet should be shoulder-width apart with slight knee flex and straight back. Ball position varies by club - forward for driver, center for irons.",
                "backswing": "Turn shoulders 90 degrees while keeping left arm straight (for right-handed golfers). Create width and maintain spine angle.",
                "downswing": "Start with hips, then shoulders, creating lag with the club. Feel like you're pulling the club down with your lead side.",
                "follow_through": "Complete the swing with balanced finish, weight on front foot. Your belt buckle should face the target.",
                "tempo": "Maintain consistent rhythm. Try a 3:1 ratio - backswing takes 3 beats, downswing takes 1 beat."
            },
            "club_distances": {
                "driver": {"avg_distance": 250, "range": "200-300", "loft": "8.5-12°"},
                "3_wood": {"avg_distance": 225, "range": "180-250", "loft": "13-16°"},
                "5_wood": {"avg_distance": 210, "range": "170-230", "loft": "17-19°"},
                "3_iron": {"avg_distance": 190, "range": "160-210", "loft": "18-22°"},
                "4_iron": {"avg_distance": 180, "range": "150-200", "loft": "22-25°"},
                "5_iron": {"avg_distance": 170, "range": "140-190", "loft": "25-28°"},
                "6_iron": {"avg_distance": 160, "range": "130-180", "loft": "28-32°"},
                "7_iron": {"avg_distance": 150, "range": "120-170", "loft": "32-36°"},
                "8_iron": {"avg_distance": 140, "range": "110-160", "loft": "36-40°"},
                "9_iron": {"avg_distance": 130, "range": "100-150", "loft": "40-45°"},
                "pw": {"avg_distance": 120, "range": "90-140", "loft": "45-48°"},
                "gw": {"avg_distance": 105, "range": "80-125", "loft": "49-53°"},
                "sw": {"avg_distance": 90, "range": "60-110", "loft": "54-58°"},
                "lw": {"avg_distance": 75, "range": "40-95", "loft": "59-64°"}
            },
            "wedge_guide": {
                "pitching_wedge": {
                    "loft": "45-48°",
                    "best_for": "Full shots 100-120 yards, chip shots with roll",
                    "typical_use": "Approach shots, basic chipping"
                },
                "gap_wedge": {
                    "loft": "49-53°", 
                    "best_for": "80-105 yard shots, versatile short game",
                    "typical_use": "Fills gap between PW and SW, greenside shots"
                },
                "sand_wedge": {
                    "loft": "54-58°",
                    "best_for": "Bunker shots, 60-90 yard approaches, high soft shots",
                    "typical_use": "Sand play, flop shots, tight lies around green"
                },
                "lob_wedge": {
                    "loft": "59-64°",
                    "best_for": "High, soft shots over obstacles, 40-75 yards",
                    "typical_use": "Flop shots, very short approaches, tight pin positions"
                }
            },
            "course_strategy": {
                "tee_shots": "Play to your strengths. If you slice, aim left of center. Course management beats distance.",
                "approach_shots": "Always take enough club. Pin hunting is for low handicappers. Aim for center of green.",
                "short_game": "Get the ball rolling as soon as possible. Putting > chipping > pitching in terms of consistency.",
                "putting": "Speed control is more important than line. Lag putting to 3-foot circle, then be aggressive."
            },
            "common_problems": {
                "slice": "Ball curves left-to-right. Usually caused by open clubface and out-to-in swing path. Strengthen grip and practice inside-out swing.",
                "hook": "Ball curves right-to-left excessively. Often from strong grip and closed clubface. Weaken grip slightly and check alignment.",
                "fat_shots": "Hitting ground before ball. Usually weight stays on back foot. Focus on weight transfer to front foot through impact.",
                "thin_shots": "Ball struck above center, low trajectory. Often from trying to help ball in air. Trust loft and hit down on ball.",
                "shanks": "Ball goes sharply right off hosel. Usually standing too close or weight on toes. Check setup and maintain spine angle."
            },
            "mental_game": {
                "confidence": "Commit to every shot. Doubt creates tension and poor swings. Trust your practice and preparation.",
                "course_management": "Play within your abilities. Take medicine when in trouble rather than attempting hero shots.",
                "pre_shot_routine": "Develop consistent routine: visualize shot, pick target, take practice swing, commit and execute.",
                "pressure": "Focus on process, not outcome. Breathe deeply and stick to your routine under pressure."
            },
            "equipment_fitting": {
                "driver": "Higher loft for slower swing speeds. Adjust for ball flight - add loft to reduce slice.",
                "irons": "Proper lie angle crucial for accuracy. Upright lies for tall players, flat lies for shorter players.",
                "wedges": "Gap your wedges properly. 4-6 degree gaps between wedges work well for most players.",
                "putter": "Length should allow comfortable setup with eyes over ball. Weight and feel are personal preference."
            },
            "swing_plane": {
                "on_plane": "Your swing plane is on the correct angle (35-55° from vertical). This promotes solid contact and consistent ball flight. Focus on maintaining this plane throughout your swing.",
                "too_steep": "Your swing plane is too steep (>55° from vertical). This can cause fat shots and loss of distance. Try flattening your backswing by turning your shoulders more and keeping your hands closer to your body.",
                "too_flat": "Your swing plane is too flat (<35° from vertical). This can cause thin shots and hooks. Try steepening your swing by feeling like you're swinging more upright and getting your hands higher in the backswing."
            },
            "equipment": {
                "driver": "Choose driver loft based on your swing speed and attack angle. Higher loft for slower speeds or steep attack angles. Adjust for ball flight tendencies.",
                "irons": "Proper lie angle is crucial for accuracy. Get fitted to ensure the sole sits flat at impact. Consider cavity backs for forgiveness or blades for workability.",
                "wedges": "Most players benefit from 3-4 wedges with consistent gaps. Consider bounce based on your swing type and course conditions.",
                "putter": "Length should allow comfortable setup with eyes over the ball. Weight and head shape are personal preferences based on your putting stroke."
            },
            "rules": {
                "stroke_play": "In stroke play, count every stroke including penalties. Lowest total score wins. Play the ball as it lies unless specific relief is allowed.",
                "match_play": "In match play, you compete hole by hole. Win more holes than your opponent to win the match. Conceded putts are allowed.",
                "out_of_bounds": "White stakes or lines mark out of bounds. Take stroke and distance penalty - replay from original spot with one penalty stroke.",
                "water_hazard": "Yellow stakes (regular hazard) or red stakes (lateral hazard). Options include stroke and distance, drop behind hazard, or lateral relief for red hazards."
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
        """Enhanced conversational golf question answering with context awareness"""
        
        if not self.is_golf_question(question):
            return "I can only answer golf-related questions. Please ask me about golf swings, tournaments, rules, equipment, or course strategy!"
        
        # Add to conversation history
        self.conversation_history.append({"question": question, "timestamp": datetime.now()})
        
        question_lower = question.lower()
        
        # Extract yardage from question for club selection
        yardage_match = re.search(r'\b(\d{1,3})\s*(?:yard|yd)s?\b', question_lower)
        yardage = int(yardage_match.group(1)) if yardage_match else None
        
        # Club selection and comparison queries (like "52 vs 58 degree")
        if self._is_club_selection_question(question_lower):
            return self._answer_club_selection_question(question_lower, yardage)
        
        # Distance/yardage queries
        if yardage and ("club" in question_lower or "use" in question_lower or "hit" in question_lower):
            return self._recommend_club_for_distance(yardage, question_lower)
        
        # Specific problem-solving queries
        if self._is_problem_solving_question(question_lower):
            return self._answer_problem_solving_question(question_lower)
        
        # Tournament/winner queries
        if any(word in question_lower for word in ["winner", "won", "champion", "masters", "us open", "british open", "pga championship"]):
            response = self._answer_tournament_question(question_lower)
            self.user_context["last_topic"] = "tournaments"
            return response
        
        # Swing technique queries
        if any(word in question_lower for word in ["swing", "plane", "grip", "stance", "backswing", "downswing", "tempo"]):
            response = self._answer_swing_question(question_lower)
            self.user_context["last_topic"] = "swing_technique"
            return response
        
        # Equipment queries
        if any(word in question_lower for word in ["club", "driver", "iron", "wedge", "putter", "equipment", "fitting"]):
            response = self._answer_equipment_question(question_lower)
            self.user_context["last_topic"] = "equipment"
            return response
        
        # Course strategy queries
        if any(word in question_lower for word in ["strategy", "course", "management", "approach", "tee shot"]):
            response = self._answer_strategy_question(question_lower)
            self.user_context["last_topic"] = "strategy"
            return response
        
        # Rules queries
        if any(word in question_lower for word in ["rule", "penalty", "relief", "out of bounds", "water hazard"]):
            response = self._answer_rules_question(question_lower)
            self.user_context["last_topic"] = "rules"
            return response
        
        # Follow-up or contextual responses
        if self._is_followup_question(question_lower):
            return self._handle_followup_question(question_lower)
        
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
    
    def _is_club_selection_question(self, question: str) -> bool:
        """Check if question is about club selection or comparison"""
        patterns = [
            r'\d{2,3}?\s*(?:degree|°)', # "52 degree" or "58°"
            r'vs|versus|or|better',     # comparison words
            r'wedge.*wedge',            # "wedge vs wedge"
            r'should i use|what club|which club'
        ]
        return any(re.search(pattern, question) for pattern in patterns)
    
    def _answer_club_selection_question(self, question: str, yardage: Optional[int]) -> str:
        """Handle specific club selection and comparison questions"""
        
        # Extract degrees if mentioned
        degree_matches = re.findall(r'(\d{2,3})\s*(?:degree|°)', question)
        degrees = [int(d) for d in degree_matches]
        
        # Handle specific wedge comparison like "52 vs 58 degree for 80 yards"
        if len(degrees) == 2 and yardage:
            deg1, deg2 = degrees[0], degrees[1]
            return self._compare_wedges_for_distance(deg1, deg2, yardage)
        elif len(degrees) == 2:
            deg1, deg2 = degrees[0], degrees[1]
            return self._compare_wedges_general(deg1, deg2)
        
        # Handle single club questions
        if yardage:
            return self._recommend_club_for_distance(yardage, question)
        
        # General club selection advice
        if "wedge" in question:
            return self._wedge_selection_advice()
        
        return "I'd love to help with club selection! Could you be more specific about the distance or situation you're facing?"
    
    def _compare_wedges_for_distance(self, deg1: int, deg2: int, yardage: int) -> str:
        """Compare two wedges for a specific distance"""
        
        # Determine wedge types
        wedge1_type = self._get_wedge_type(deg1)
        wedge2_type = self._get_wedge_type(deg2)
        
        response = f"Great question! For {yardage} yards, here's my recommendation:\n\n"
        
        if yardage <= 60:
            higher_loft = max(deg1, deg2)
            response += f"**{higher_loft}° wedge** would be better for {yardage} yards.\n"
            response += f"• Higher loft = softer landing and more spin\n"
            response += f"• Better for tight pin positions\n"
            response += f"• More margin for error on short shots"
        elif yardage <= 80:
            if abs(deg1 - deg2) <= 6:  # Close in loft
                response += f"Both wedges could work for {yardage} yards! Here's the difference:\n\n"
                response += f"**{deg1}° ({wedge1_type}):** More roll, lower trajectory\n"
                response += f"**{deg2}° ({wedge2_type}):** Higher, softer landing\n\n"
                response += f"Choose based on pin position and green conditions."
            else:
                lower_loft = min(deg1, deg2)
                response += f"**{lower_loft}° wedge** is better for {yardage} yards.\n"
                response += f"• More distance with controlled trajectory\n"
                response += f"• Easier to make solid contact"
        else:  # 80+ yards
            lower_loft = min(deg1, deg2)
            response += f"**{lower_loft}° wedge** is definitely better for {yardage} yards.\n"
            response += f"• You'll need the lower loft for distance\n"
            response += f"• Higher lofted wedge would require too aggressive a swing"
        
        response += f"\n💡 **Pro tip:** Practice both clubs to know your exact carry distances!"
        return response
    
    def _compare_wedges_general(self, deg1: int, deg2: int) -> str:
        """Compare two wedges without specific distance"""
        wedge1_type = self._get_wedge_type(deg1)
        wedge2_type = self._get_wedge_type(deg2)
        
        response = f"**{deg1}° vs {deg2}° Wedge Comparison:**\n\n"
        response += f"**{deg1}° ({wedge1_type}):**\n"
        response += f"• {self.golf_knowledge['wedge_guide'][wedge1_type]['best_for']}\n"
        response += f"• {self.golf_knowledge['wedge_guide'][wedge1_type]['typical_use']}\n\n"
        
        response += f"**{deg2}° ({wedge2_type}):**\n"
        response += f"• {self.golf_knowledge['wedge_guide'][wedge2_type]['best_for']}\n"
        response += f"• {self.golf_knowledge['wedge_guide'][wedge2_type]['typical_use']}\n\n"
        
        response += f"**Bottom line:** Higher loft = shorter distance but softer landing. Choose based on your typical shot needs!"
        return response
    
    def _get_wedge_type(self, degrees: int) -> str:
        """Determine wedge type from loft degrees"""
        if degrees <= 48:
            return "pitching_wedge"
        elif degrees <= 53:
            return "gap_wedge" 
        elif degrees <= 58:
            return "sand_wedge"
        else:
            return "lob_wedge"
    
    def _recommend_club_for_distance(self, yardage: int, context: str = "") -> str:
        """Recommend best club for specific yardage"""
        
        recommendations = []
        
        # Find clubs that fit the yardage
        for club, data in self.golf_knowledge["club_distances"].items():
            range_parts = data["range"].split("-")
            min_dist = int(range_parts[0])
            max_dist = int(range_parts[1])
            
            if min_dist <= yardage <= max_dist:
                recommendations.append({
                    "club": club,
                    "avg": data["avg_distance"],
                    "range": data["range"],
                    "loft": data.get("loft", "")
                })
        
        if not recommendations:
            return f"For {yardage} yards, you might need a different club than what's in my standard chart. Could you tell me more about the situation?"
        
        # Sort by how close the average distance is to target
        recommendations.sort(key=lambda x: abs(x["avg"] - yardage))
        best_match = recommendations[0]
        
        response = f"For **{yardage} yards**, I'd recommend:\n\n"
        response += f"**Primary choice: {best_match['club'].replace('_', ' ').title()}**\n"
        response += f"• Average distance: {best_match['avg']} yards\n"
        response += f"• Typical range: {best_match['range']} yards\n"
        
        if len(recommendations) > 1:
            alt = recommendations[1]
            response += f"\n**Alternative: {alt['club'].replace('_', ' ').title()}**\n"
            response += f"• Average distance: {alt['avg']} yards\n"
            
        response += f"\n💡 **Remember:** These are averages. Your distances may vary based on swing speed, conditions, and course elevation!"
        
        # Add situational advice
        if "uphill" in context or "elevated" in context:
            response += f"\n⛰️ **Uphill shot:** Take one club longer"
        elif "downhill" in context:
            response += f"\n⬇️ **Downhill shot:** Take one club shorter"
        if "wind" in context:
            response += f"\n💨 **Windy conditions:** Adjust club selection accordingly"
            
        return response
    
    def _is_problem_solving_question(self, question: str) -> bool:
        """Check if question is about fixing a specific problem"""
        problem_words = ["fix", "help", "problem", "slice", "hook", "shank", "fat", "thin", "improve", "better"]
        return any(word in question for word in problem_words)
    
    def _answer_problem_solving_question(self, question: str) -> str:
        """Handle questions about fixing golf problems"""
        
        problems = {
            "slice": "slice",
            "hook": "hook", 
            "fat": "fat_shots",
            "thin": "thin_shots",
            "shank": "shanks"
        }
        
        for keyword, problem_key in problems.items():
            if keyword in question:
                advice = self.golf_knowledge["common_problems"][problem_key]
                response = f"**Fixing your {keyword}:**\n\n{advice}\n\n"
                response += f"💡 **Practice tip:** Start with slow, controlled swings focusing on the fundamentals, then gradually increase speed."
                return response
        
        # General improvement advice
        if any(word in question for word in ["improve", "better", "consistent"]):
            return self._general_improvement_advice()
        
        return "I'd be happy to help you improve! What specific issue are you facing with your game?"
    
    def _general_improvement_advice(self) -> str:
        """Provide general improvement advice"""
        return ("**Keys to Better Golf:**\n\n"
                "1. **Fundamentals first:** Master grip, stance, and alignment\n"
                "2. **Short game focus:** 60% of shots are within 100 yards\n"
                "3. **Course management:** Play smart, not just long\n"
                "4. **Consistent practice:** Quality over quantity\n"
                "5. **Mental game:** Stay positive and committed to each shot\n\n"
                "💡 **Start with:** Get lessons on fundamentals, then practice your short game regularly!")
    
    def _answer_strategy_question(self, question: str) -> str:
        """Handle course strategy questions"""
        
        if "tee" in question or "driver" in question:
            return f"**Tee Shot Strategy:**\n{self.golf_knowledge['course_strategy']['tee_shots']}\n\n💡 **Remember:** Fairway position is more important than maximum distance!"
        
        elif "approach" in question or "green" in question:
            return f"**Approach Shot Strategy:**\n{self.golf_knowledge['course_strategy']['approach_shots']}\n\n💡 **Club up:** It's better to be long than short!"
        
        elif "short game" in question or "chipping" in question:
            return f"**Short Game Strategy:**\n{self.golf_knowledge['course_strategy']['short_game']}\n\n💡 **Get it rolling:** The ball rolls more predictably than it flies!"
        
        elif "putting" in question or "putt" in question:
            return f"**Putting Strategy:**\n{self.golf_knowledge['course_strategy']['putting']}\n\n💡 **Speed over line:** A putt with good speed has a chance even if line is slightly off!"
        
        return "Course strategy is crucial for lower scores! What specific situation would you like help with - tee shots, approaches, short game, or putting?"
    
    def _wedge_selection_advice(self) -> str:
        """Provide comprehensive wedge selection advice"""
        response = "**Wedge Selection Guide:**\n\n"
        
        for wedge_type, info in self.golf_knowledge["wedge_guide"].items():
            name = wedge_type.replace("_", " ").title()
            response += f"**{name} ({info['loft']}):**\n"
            response += f"• {info['best_for']}\n"
            response += f"• {info['typical_use']}\n\n"
        
        response += "💡 **Pro tip:** Most golfers benefit from 3-4 wedges with 4-6° gaps between them!"
        return response
    
    def _is_followup_question(self, question: str) -> bool:
        """Check if this might be a follow-up question"""
        followup_words = ["what about", "how about", "and", "also", "but", "what if", "okay but"]
        return any(phrase in question for phrase in followup_words) and len(self.conversation_history) > 1
    
    def _handle_followup_question(self, question: str) -> str:
        """Handle follow-up questions based on conversation context"""
        
        if not self.user_context.get("last_topic"):
            return "I'd be happy to help! Could you be more specific about what you'd like to know?"
        
        last_topic = self.user_context["last_topic"]
        
        if last_topic == "equipment" and ("distance" in question or "yard" in question):
            return "Absolutely! Club distances can vary significantly based on your swing speed, course conditions, and altitude. Would you like me to help you figure out your personal yardages for specific clubs?"
        
        elif last_topic == "swing_technique" and ("practice" in question or "drill" in question):
            return "Great question! Here are some effective practice drills:\n\n• **Mirror work:** Practice your setup and swing positions\n• **Slow motion swings:** Focus on proper sequence\n• **Impact bag:** Improve your impact position\n• **Alignment sticks:** Ensure proper aim and swing path\n\nWhat specific part of your swing would you like to work on?"
        
        return f"I see you're still interested in {last_topic.replace('_', ' ')}! What specific aspect would you like to explore further?"
    
    def _general_golf_response(self, question: str) -> str:
        """Enhanced general golf response"""
        return ("I'm your personal golf caddie! I can help you with:\n\n"
                "🏌️ **Club Selection:** 'What club for 85 yards?' or '52° vs 58° wedge?'\n"
                "🎯 **Course Strategy:** Tee shots, approach shots, short game tactics\n"
                "🔧 **Fix Problems:** Slice, hook, fat shots, consistency issues\n"
                "📚 **Fundamentals:** Grip, stance, swing mechanics, mental game\n"
                "🏆 **Tournament Info:** PGA major winners and golf history\n"
                "⚖️ **Rules & Equipment:** What's legal, when to take relief\n\n"
                "What can I help you with today?")

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
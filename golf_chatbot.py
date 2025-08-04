#!/usr/bin/env python3
"""
CaddieChat Pro - Advanced Conversational Golf AI Assistant
A leading golf chatbot with comprehensive knowledge, personalized advice, and natural conversation
"""

import json
import re
import random
from datetime import datetime, date, timedelta
from typing import Dict, List, Optional, Any, Tuple
import math

class CaddieChat:
    """CaddieChat Pro - Leading conversational golf AI with advanced capabilities"""
    
    def __init__(self):
        self.pga_major_winners = self._load_pga_data()
        self.golf_knowledge = self._load_golf_knowledge()
        self.player_stats = self._load_player_stats()
        self.course_database = self._load_course_database()
        self.weather_factors = self._load_weather_factors()
        self.conversation_history = []
        self.user_context = {
            "handicap": None,
            "swing_speed": None,
            "preferred_clubs": [],
            "course_conditions": None,
            "swing_tendencies": [],
            "last_topic": None,
            "playing_style": None,
            "experience_level": None,
            "recent_issues": [],
            "goals": []
        }
        self.greeting_responses = [
            "Hey there, golfer! Ready to improve your game?",
            "Welcome to the pro shop of golf knowledge! What can I help you with?",
            "Great to see you on the course today! How can I caddie for you?",
            "Let's talk golf! I'm here to help you play smarter and score better.",
            "Time to elevate your golf game! What's on your mind?"
        ]
        
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
    
    def _load_player_stats(self) -> Dict:
        """Load professional player statistics and achievements"""
        return {
            "tiger_woods": {
                "majors": 15,
                "pga_wins": 82,
                "achievements": ["Career Grand Slam", "Tiger Slam (2000-2001)", "Youngest Masters winner"],
                "best_year": "2000 (3 majors, 9 PGA wins)",
                "comeback": "2019 Masters after back surgeries",
                "specialties": ["Clutch putting", "Iron play", "Mental toughness"]
            },
            "jack_nicklaus": {
                "majors": 18,
                "pga_wins": 73,
                "achievements": ["Most major championships", "Golden Bear", "6 Masters wins"],
                "best_year": "1972 (2 majors, 7 PGA wins)",
                "legacy": "Greatest golfer of all time debate",
                "specialties": ["Course management", "Longevity", "Major championship performance"]
            },
            "rory_mcilroy": {
                "majors": 4,
                "pga_wins": 21,
                "achievements": ["Youngest to reach $10M in earnings", "FedEx Cup Champion"],
                "best_year": "2014 (2 majors, 3 PGA wins)",
                "strengths": ["Driving distance", "Iron accuracy", "Athleticism"],
                "note": "Seeking Masters win to complete Career Grand Slam"
            },
            "scottie_scheffler": {
                "majors": 2,
                "pga_wins": 12,
                "achievements": ["World #1", "2022 Masters Champion", "FedEx Cup Champion"],
                "best_year": "2022 (1 major, 4 PGA wins)",
                "strengths": ["Consistency", "All-around game", "Mental strength"],
                "current_form": "Dominant player 2022-2024"
            }
        }
    
    def _load_course_database(self) -> Dict:
        """Load famous golf course information and playing tips"""
        return {
            "augusta_national": {
                "location": "Augusta, Georgia",
                "par": 72,
                "yardage": 7435,
                "signature_holes": ["12th (Golden Bell)", "13th (Azalea)", "16th (Redbud)"],
                "key_features": ["Lightning-fast greens", "Amen Corner", "Downhill lies"],
                "playing_tips": ["Course management crucial", "Avoid going long on approach shots", "Putting is everything"],
                "notable": "Home of The Masters Tournament since 1934"
            },
            "pebble_beach": {
                "location": "Pebble Beach, California",
                "par": 72,
                "yardage": 6828,
                "signature_holes": ["7th (oceanside par-3)", "8th (short par-4)", "18th (ocean finish)"],
                "key_features": ["Ocean winds", "Small greens", "Dramatic coastline"],
                "playing_tips": ["Club up for ocean winds", "Precision over power", "Lag putting essential"],
                "notable": "Host of US Open, AT&T Pro-Am"
            },
            "st_andrews": {
                "location": "St. Andrews, Scotland",
                "par": 72,
                "yardage": 7297,
                "signature_holes": ["17th (Road Hole)", "18th (Valley of Sin)", "Hell Bunker"],
                "key_features": ["Double greens", "Deep bunkers", "Variable weather"],
                "playing_tips": ["Study wind patterns", "Avoid pot bunkers", "Use ground game"],
                "notable": "The Home of Golf - oldest golf course in the world"
            }
        }
    
    def _load_weather_factors(self) -> Dict:
        """Load weather playing conditions and adjustments"""
        return {
            "wind": {
                "headwind": {
                    "club_adjustment": "1-2 clubs longer",
                    "ball_flight": "Lower trajectory helps",
                    "strategy": "Punch shots, controlled swings"
                },
                "tailwind": {
                    "club_adjustment": "1 club shorter",
                    "ball_flight": "Higher shots carry further",
                    "strategy": "Aggressive pin hunting opportunities"
                },
                "crosswind": {
                    "club_adjustment": "Aim adjustment needed",
                    "ball_flight": "Account for drift",
                    "strategy": "Play into wind or ride it"
                }
            },
            "rain": {
                "wet_conditions": {
                    "distance_loss": "10-15% less carry",
                    "club_selection": "Take extra club",
                    "strategy": "Avoid flyer lies, club up"
                },
                "soft_greens": {
                    "approach_shots": "Can be more aggressive",
                    "spin": "Less roll, more stopping power",
                    "putting": "Slower green speeds"
                }
            },
            "temperature": {
                "cold": {
                    "distance_loss": "5-10 yards per club",
                    "ball_compression": "Reduced with cold balls",
                    "strategy": "Warm up thoroughly, extra club"
                },
                "hot": {
                    "distance_gain": "5-10 yards extra carry",
                    "ball_compression": "Better in heat",
                    "strategy": "Stay hydrated, club down slightly"
                }
            },
            "altitude": {
                "high_altitude": {
                    "distance_gain": "8-10% more distance",
                    "ball_flight": "Less air resistance",
                    "strategy": "Club down, account for extra roll"
                }
            }
        }
    
    def _load_golf_knowledge(self) -> Dict:
        """Load comprehensive golf knowledge base with detailed guidance"""
        return {
            "premium_swing_analysis": {
                "swing_flaws": {
                    "slice": {
                        "cause": "Open clubface relative to swing path, usually with out-to-in swing",
                        "fixes": ["Strengthen grip (see 2-3 knuckles)", "Practice inside-out swing path", "Close stance slightly", "Check ball position (not too far forward)"],
                        "drills": ["Alignment stick drill outside ball", "Door frame drill for inside takeaway", "Headcover under right armpit drill"],
                        "impact": "Major distance loss, accuracy issues, frustration"
                    },
                    "hook": {
                        "cause": "Closed clubface relative to swing path, often strong grip",
                        "fixes": ["Weaken grip slightly", "Open stance", "Hold off release through impact", "Check ball position"],
                        "drills": ["Practice fade shots on range", "Impact bag work", "Slow motion swings focusing on face control"],
                        "impact": "Loss of control, trouble with course management"
                    },
                    "early_extension": {
                        "cause": "Hips and torso move toward ball during downswing",
                        "fixes": ["Maintain spine angle", "Focus on rotating, not sliding", "Strengthen core", "Practice wall drill"],
                        "drills": ["Wall drill - setup with butt against wall", "Chair drill for proper hip turn", "Impact position holds"],
                        "impact": "Inconsistent contact, loss of power, fat/thin shots"
                    },
                    "power_loss": {
                        "cause": "Poor weight transfer, casting, lack of lag, tempo issues",
                        "fixes": ["Improve weight transfer to front foot", "Create and maintain lag", "Strengthen core and legs", "Practice tempo drills"],
                        "drills": ["Step-through drill", "Pump drill for lag", "Medicine ball throws", "Metronome tempo work"],
                        "impact": "Shorter distances despite good contact"
                    },
                    "spine_angle": {
                        "cause": "Loss of posture during swing, standing up or dipping",
                        "fixes": ["Maintain flex in knees", "Keep chest over ball longer", "Strengthen glutes and core", "Practice mirror work"],
                        "drills": ["Mirror work for posture", "Chair drill", "Balance board training", "Video analysis checkpoints"],
                        "impact": "Inconsistent ball striking, loss of power and accuracy"
                    }
                },
                "launch_monitor_interpretation": {
                    "club_speed": "Speed of clubhead at impact. Faster = more distance potential",
                    "ball_speed": "Speed of ball immediately after impact. Higher is better",
                    "smash_factor": "Ball speed ÷ club speed. Driver: 1.48-1.50 is excellent, 1.44+ is good",
                    "launch_angle": "Initial trajectory. Driver: 10-14° optimal, varies by swing speed",
                    "spin_rate": "RPM of ball. Driver: 2000-2800 optimal. Too high = distance loss",
                    "carry_distance": "Distance ball travels in air before first bounce",
                    "attack_angle": "Club's vertical approach. Driver: +2° to +5° up. Irons: -2° to -4° down",
                    "dynamic_loft": "Actual loft at impact (different from static loft)"
                },
                "tempo_rhythm": {
                    "ideal_ratio": "3:1 backswing to downswing timing",
                    "drills": ["Count '1-2-3' up, '1' down", "Metronome practice", "Orange whip training", "Pause at top drill"],
                    "benefits": "Better timing, more consistent contact, improved accuracy",
                    "common_issues": "Rushing transition, decelerating through impact"
                }
            },
            "advanced_concepts": {
                "ball_flight_laws": {
                    "draw": "Ball curves right to left (for right-handed golfers). Created by clubface closed to swing path. Useful for shaping shots around obstacles.",
                    "fade": "Ball curves left to right (for right-handed golfers). Created by clubface open to swing path. More predictable and controllable than a draw.",
                    "straight": "Clubface square to target at impact with swing path matching clubface angle. Requires precise timing and setup.",
                    "slice": "Excessive left-to-right curve. Usually unwanted. Caused by very open clubface relative to swing path.",
                    "hook": "Excessive right-to-left curve. Usually unwanted. Caused by very closed clubface relative to swing path."
                },
                "distance_factors": {
                    "swing_speed": "Primary factor in distance. Every 1 mph increase = ~2.5 yards more carry",
                    "launch_angle": "Optimal for driver: 10-14°. Higher for slower swing speeds",
                    "spin_rate": "Driver: 2000-2800 RPM optimal. Too much = distance loss",
                    "attack_angle": "Driver: +2° to +5° up. Irons: -2° to -4° down",
                    "equipment_fit": "Proper shaft flex and club fitting can add 10-20 yards"
                },
                "short_game_advanced": {
                    "chipping_ratios": "General rule: 1/3 carry, 2/3 roll for basic chips",
                    "wedge_bounce": "High bounce (12°+) for soft conditions, low bounce (4-8°) for firm conditions",
                    "putting_read": "Speed determines break. Faster putts break less, slower putts break more",
                    "greenside_strategy": "Get ball rolling ASAP. Putt when you can, chip when you can't putt, pitch when you must"
                }
            },
            "swing_plane": {
                "on_plane": "Your swing plane is on the correct angle (35-55° from vertical). This promotes solid contact and consistent ball flight. Focus on maintaining this plane throughout your swing.",
                "too_steep": "Your swing plane is too steep (>55° from vertical). This can cause fat shots and loss of distance. Try flattening your backswing by turning your shoulders more and keeping your hands closer to your body.",
                "too_flat": "Your swing plane is too flat (<35° from vertical). This can cause thin shots and hooks. Try steepening your swing by feeling like you're swinging more upright and getting your hands higher in the backswing."
            },
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
            "practice_routines": {
                "weekly_18_handicap": {
                    "monday": "20 min putting (lag putts, 3-footers)",
                    "tuesday": "30 min short game (chipping, pitching)",
                    "wednesday": "Range - 7 iron tempo, then mixed clubs",
                    "thursday": "Course management practice round",
                    "friday": "Rest or light putting",
                    "saturday": "Pre-round warmup routine",
                    "sunday": "Play and track stats"
                },
                "30_minute_short_game": {
                    "5_min": "Putting warm-up (3-6 foot circle)",
                    "10_min": "Chipping - various lies and distances",
                    "10_min": "Pitching - 30-60 yard shots",
                    "5_min": "Pressure putting - make 5 in a row from 3 feet"
                },
                "putting_drills": {
                    "pace_control": "Ladder drill - 10, 20, 30, 40 foot putts",
                    "gate_drill": "Two tees just wider than putter for stroke path",
                    "clock_drill": "6 balls around hole at 3 feet, make all 6",
                    "lag_putting": "Try to get all long putts within 3-foot circle"
                },
                "warmup_routine": {
                    "5_min": "Stretching - shoulders, hips, hamstrings",
                    "5_min": "Putting - feel for green speed",
                    "5_min": "Chipping - get hands active",
                    "10_min": "Range - start with wedges, work up to driver",
                    "5_min": "Practice swings with course club selection"
                }
            },
            "fitness_golf": {
                "flexibility": {
                    "shoulder_turn": ["Doorway chest stretch", "Cross-body shoulder stretch", "Wall slides", "Thoracic spine rotation"],
                    "hip_mobility": ["Hip flexor stretch", "Pigeon pose", "Hip circles", "90-90 hip stretch"],
                    "rotation": ["Russian twists", "Medicine ball throws", "Cable wood chops", "Seated spinal twist"]
                },
                "strength": {
                    "core": ["Planks", "Dead bugs", "Bird dogs", "Pallof press", "Anti-rotation holds"],
                    "glutes": ["Squats", "Lunges", "Hip thrusts", "Clamshells", "Monster walks"],
                    "swing_speed": ["Medicine ball slams", "Resistance band pulls", "Plyometric movements", "Speed training swings"]
                },
                "injury_prevention": {
                    "back_pain": ["Cat-cow stretches", "Hip flexor stretches", "Glute strengthening", "Core stability work"],
                    "common_causes": "Poor posture, weak core, tight hips, over-swinging",
                    "prevention": "Regular stretching, proper warmup, strength training, lesson on swing mechanics"
                }
            },
            "advanced_strategy": {
                "narrow_fairway": "Club down for accuracy, aim for widest part, accept shorter distance for position",
                "par_5_water": "Lay up to comfortable yardage, avoid going for green in two unless you're confident",
                "pressure_situations": "Stick to routine, focus on process not outcome, take deep breaths, commit fully",
                "mental_game": {
                    "focus_techniques": ["Pre-shot routine", "Visualization", "Breathing exercises", "Target-focused thinking"],
                    "bad_hole_recovery": "Accept it happened, focus on next shot, use it as learning experience",
                    "confidence_building": "Practice success scenarios, positive self-talk, remember good shots"
                }
            },
            "rules_detailed": {
                "loose_impediments": "Can move loose impediments (leaves, twigs) except in hazards. Cannot move if ball moves.",
                "wrong_ball": "2-stroke penalty in stroke play, loss of hole in match play. Must correct before next tee.",
                "pace_of_play": "Keep up with group ahead, be ready to play, help others look for balls max 3 minutes",
                "penalty_drops": {
                    "unplayable": "1 stroke: back on line, 2 club lengths, or stroke and distance",
                    "water_hazard": "1 stroke: last point of entry relief, or stroke and distance",
                    "out_of_bounds": "Stroke and distance penalty - replay from original spot"
                }
            },
            "equipment_advanced": {
                "shaft_flex": {
                    "guide": "L (Ladies): <60 mph, A (Senior): 60-70 mph, R (Regular): 70-80 mph, S (Stiff): 80-90 mph, X (Extra Stiff): 90+ mph",
                    "fitting_importance": "Wrong flex affects accuracy, distance, and ball flight. Get properly fitted.",
                    "swing_speed_test": "Use launch monitor or speed training device for accurate measurement"
                },
                "club_fitting": {
                    "benefits": "10-20 yard distance gain possible, improved accuracy, better feel",
                    "key_measurements": "Height, wrist-to-floor, swing speed, ball flight tendencies",
                    "fitting_process": "Dynamic fitting with ball flight analysis beats static measurements",
                    "cost_benefit": "Fitting costs $100-300 but can improve scores more than lessons for some golfers"
                },
                "iron_types": {
                    "blades": "Maximum workability and feel, less forgiving, for skilled players",
                    "cavity_back": "More forgiving, easier to hit, good for mid-handicappers",
                    "game_improvement": "Maximum forgiveness, distance help, best for high handicappers"
                },
                "regripping": "Every 40 rounds or annually. Worn grips cause tension and poor shots."
            },
            "statistics_improvement": {
                "key_stats": {
                    "gir": "Greens in regulation. 18-handicap: 22%, 10-handicap: 44%, scratch: 67%",
                    "fairways": "Driving accuracy. More important than distance for scoring",
                    "putts_per_round": "18-handicap: 36, 10-handicap: 32, scratch: 29",
                    "up_and_down": "Getting up and down from around green. Critical for scoring"
                },
                "handicap_improvement": {
                    "18_to_12": "Focus on short game, course management, eliminate big numbers",
                    "12_to_6": "Improve iron accuracy, putting consistency, mental game",
                    "6_to_scratch": "Fine-tune everything, tournament experience, mental toughness"
                },
                "tracking_apps": "Use apps like Arccos, Shot Scope, or Grint to identify weaknesses"
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
            "chip", "pitch", "putt", "approach", "yardage", "loft", "lie",
            # Enhanced keywords for premium features
            "wind", "windy", "rain", "weather", "temperature", "cold", "hot",
            "augusta", "pebble", "andrews", "nicklaus", "mcilroy", "scheffler",
            "player", "career", "wins", "majors", "short game", "improve",
            "conditions", "tailwind", "headwind", "crosswind", "wet",
            # Premium swing analysis keywords
            "spine angle", "early extension", "power", "tempo", "rhythm",
            "launch monitor", "spin rate", "smash factor", "launch angle",
            # Practice and fitness keywords  
            "practice", "drill", "routine", "warmup", "stretch", "fitness",
            "strength", "flexibility", "core", "back pain", "injury",
            # Strategy and mental game
            "strategy", "management", "mental", "pressure", "focus", "confidence",
            "narrow", "water", "par 5", "statistics", "stats", "handicap",
            # Equipment and fitting
            "fitting", "shaft", "flex", "blade", "cavity", "regrip", "bounce"
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
        
        # PREMIUM FEATURES - Check these first for specificity
        
        # Premium swing analysis queries (highest priority)
        if self._is_swing_analysis_question(question_lower):
            return self._answer_swing_analysis_question(question_lower)
            
        # Launch monitor and data interpretation
        if self._is_data_interpretation_question(question_lower):
            return self._answer_data_interpretation_question(question_lower)
            
        # Fitness and injury prevention (check before practice for specificity)
        if self._is_fitness_question(question_lower):
            return self._answer_fitness_question(question_lower)
            
        # Practice routines and drills
        if self._is_practice_question(question_lower):
            return self._answer_practice_question(question_lower)
            
        # Advanced equipment and fitting
        if self._is_equipment_fitting_question(question_lower):
            return self._answer_equipment_fitting_question(question_lower)
            
        # Statistics and improvement tracking
        if self._is_stats_question(question_lower):
            return self._answer_stats_question(question_lower)
            
        # Advanced strategy and mental game
        if self._is_strategy_mental_question(question_lower):
            return self._answer_strategy_mental_question(question_lower)
        
        # Club selection and comparison queries (like "52 vs 58 degree")
        if self._is_club_selection_question(question_lower):
            return self._answer_club_selection_question(question_lower, yardage)
        
        # Distance/yardage queries
        if yardage and ("club" in question_lower or "use" in question_lower or "hit" in question_lower):
            return self._recommend_club_for_distance(yardage, question_lower)
            
        # Advanced strategy and mental game
        if self._is_strategy_mental_question(question_lower):
            return self._answer_strategy_mental_question(question_lower)
            
        # Statistics and improvement tracking
        if self._is_stats_question(question_lower):
            return self._answer_stats_question(question_lower)
            
        # Advanced equipment and fitting
        if self._is_equipment_fitting_question(question_lower):
            return self._answer_equipment_fitting_question(question_lower)
        
        # Specific problem-solving queries
        if self._is_problem_solving_question(question_lower):
            return self._answer_problem_solving_question(question_lower)
        
        # Weather and playing conditions
        if any(word in question_lower for word in ["wind", "rain", "weather", "cold", "hot", "temperature", "conditions"]):
            response = self._answer_weather_question(question_lower)
            self.user_context["last_topic"] = "weather"
            return response
        
        # Player statistics and achievements
        if any(word in question_lower for word in ["tiger", "woods", "nicklaus", "mcilroy", "scheffler", "player", "career", "wins", "majors"]):
            response = self._answer_player_question(question_lower)
            self.user_context["last_topic"] = "players"
            return response
        
        # Course information and playing tips
        if any(word in question_lower for word in ["augusta", "pebble", "st andrews", "course", "hole", "green"]):
            response = self._answer_course_question(question_lower)
            self.user_context["last_topic"] = "courses"
            return response
        
        # Ball flight and shot shaping
        if any(word in question_lower for word in ["draw", "fade", "slice", "hook", "ball flight", "shape", "curve"]):
            response = self._answer_ball_flight_question(question_lower)
            self.user_context["last_topic"] = "ball_flight"
            return response
        
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
        if "majors" in question or "all" in question:
            return self._get_major_summary(year)
        
        # If no specific tournament mentioned, try to be helpful
        return f"I have detailed information about all major tournaments from 2014-2024. Which specific major would you like to know about? (Masters, US Open, British Open, or PGA Championship)"
    
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
    
    def _answer_weather_question(self, question: str) -> str:
        """Answer weather and playing conditions questions"""
        
        if "wind" in question:
            if "headwind" in question or "into" in question:
                wind_data = self.weather_factors["wind"]["headwind"]
                return f"**Playing in Headwind:**\n• {wind_data['club_adjustment']}\n• {wind_data['ball_flight']}\n• Strategy: {wind_data['strategy']}\n\n💡 **Pro tip:** Keep the ball lower to minimize wind effect!"
            elif "tailwind" in question or "behind" in question:
                wind_data = self.weather_factors["wind"]["tailwind"]
                return f"**Playing with Tailwind:**\n• {wind_data['club_adjustment']}\n• {wind_data['ball_flight']}\n• Strategy: {wind_data['strategy']}\n\n💡 **Pro tip:** Don't swing harder - let the wind do the work!"
            elif "crosswind" in question or "side" in question:
                wind_data = self.weather_factors["wind"]["crosswind"]
                return f"**Playing in Crosswind:**\n• {wind_data['club_adjustment']}\n• {wind_data['ball_flight']}\n• Strategy: {wind_data['strategy']}\n\n💡 **Pro tip:** Aim into the wind and let it bring the ball back!"
            else:
                return "**Wind Playing Tips:**\n\n• **Headwind:** Take 1-2 more clubs, keep ball flight lower\n• **Tailwind:** Take 1 less club, higher shots work well\n• **Crosswind:** Aim into the wind or ride it out\n\n💨 **General rule:** The stronger the wind, the more it affects your shot!"
        
        elif "rain" in question or "wet" in question:
            return f"**Playing in Rain/Wet Conditions:**\n\n• **Distance:** {self.weather_factors['rain']['wet_conditions']['distance_loss']}\n• **Club Selection:** {self.weather_factors['rain']['wet_conditions']['club_selection']}\n• **Greens:** {self.weather_factors['rain']['soft_greens']['approach_shots']}\n• **Putting:** {self.weather_factors['rain']['soft_greens']['putting']}\n\n☔ **Key tip:** Wet conditions are actually easier for approach shots - greens hold better!"
        
        elif "cold" in question:
            return f"**Playing in Cold Weather:**\n\n• **Distance Loss:** {self.weather_factors['temperature']['cold']['distance_loss']}\n• **Ball Performance:** {self.weather_factors['temperature']['cold']['ball_compression']}\n• **Strategy:** {self.weather_factors['temperature']['cold']['strategy']}\n\n🥶 **Pro tip:** Keep balls warm in your pocket between shots!"
        
        elif "hot" in question:
            return f"**Playing in Hot Weather:**\n\n• **Distance Gain:** {self.weather_factors['temperature']['hot']['distance_gain']}\n• **Ball Performance:** {self.weather_factors['temperature']['hot']['ball_compression']}\n• **Strategy:** {self.weather_factors['temperature']['hot']['strategy']}\n\n🔥 **Remember:** Club down slightly and stay hydrated!"
        
        return "I can help with weather conditions! Ask me about wind (headwind, tailwind, crosswind), rain, cold weather, or hot weather playing tips."
    
    def _answer_player_question(self, question: str) -> str:
        """Answer questions about professional golfers"""
        
        if "tiger" in question or "woods" in question:
            stats = self.player_stats["tiger_woods"]
            return f"**Tiger Woods Career Highlights:**\n\n• **Major Championships:** {stats['majors']} (2nd all-time)\n• **PGA Tour Wins:** {stats['pga_wins']} (tied for most all-time)\n• **Achievements:** {', '.join(stats['achievements'])}\n• **Best Year:** {stats['best_year']}\n• **Greatest Comeback:** {stats['comeback']}\n• **Key Strengths:** {', '.join(stats['specialties'])}\n\n🐅 **Legacy:** One of the greatest golfers of all time with incredible mental toughness!"
        
        elif "nicklaus" in question or "jack" in question:
            stats = self.player_stats["jack_nicklaus"]
            return f"**Jack Nicklaus Career Highlights:**\n\n• **Major Championships:** {stats['majors']} (Most all-time)\n• **PGA Tour Wins:** {stats['pga_wins']}\n• **Achievements:** {', '.join(stats['achievements'])}\n• **Best Year:** {stats['best_year']}\n• **Legacy:** {stats['legacy']}\n• **Key Strengths:** {', '.join(stats['specialties'])}\n\n🐻 **The Golden Bear:** The standard by which all golfers are measured!"
        
        elif "mcilroy" in question or "rory" in question:
            stats = self.player_stats["rory_mcilroy"]
            return f"**Rory McIlroy Career Highlights:**\n\n• **Major Championships:** {stats['majors']}\n• **PGA Tour Wins:** {stats['pga_wins']}\n• **Achievements:** {', '.join(stats['achievements'])}\n• **Best Year:** {stats['best_year']}\n• **Key Strengths:** {', '.join(stats['strengths'])}\n• **Career Goal:** {stats['note']}\n\n🍀 **Power and Precision:** One of the longest and most accurate drivers on tour!"
        
        elif "scheffler" in question or "scottie" in question:
            stats = self.player_stats["scottie_scheffler"]
            return f"**Scottie Scheffler Career Highlights:**\n\n• **Major Championships:** {stats['majors']}\n• **PGA Tour Wins:** {stats['pga_wins']}\n• **Achievements:** {', '.join(stats['achievements'])}\n• **Best Year:** {stats['best_year']}\n• **Key Strengths:** {', '.join(stats['strengths'])}\n• **Current Status:** {stats['current_form']}\n\n⭐ **Rising Star:** The most consistent player on tour with incredible all-around skills!"
        
        else:
            return "I have detailed stats on Tiger Woods, Jack Nicklaus, Rory McIlroy, and Scottie Scheffler. Which player would you like to know about?"
    
    def _answer_course_question(self, question: str) -> str:
        """Answer questions about famous golf courses"""
        
        if "augusta" in question or "masters" in question:
            course = self.course_database["augusta_national"]
            return f"**Augusta National Golf Club:**\n\n• **Location:** {course['location']}\n• **Par/Yardage:** {course['par']}, {course['yardage']} yards\n• **Signature Holes:** {', '.join(course['signature_holes'])}\n• **Key Features:** {', '.join(course['key_features'])}\n• **Playing Tips:** {', '.join(course['playing_tips'])}\n\n🌺 **The Masters:** {course['notable']}\n\n💡 **Remember:** Augusta rewards precision and course management over pure power!"
        
        elif "pebble" in question:
            course = self.course_database["pebble_beach"]
            return f"**Pebble Beach Golf Links:**\n\n• **Location:** {course['location']}\n• **Par/Yardage:** {course['par']}, {course['yardage']} yards\n• **Signature Holes:** {', '.join(course['signature_holes'])}\n• **Key Features:** {', '.join(course['key_features'])}\n• **Playing Tips:** {', '.join(course['playing_tips'])}\n\n🌊 **Oceanfront Beauty:** {course['notable']}\n\n💡 **Wind Management:** The Pacific Ocean winds can dramatically affect your shots!"
        
        elif "st andrews" in question or "andrews" in question:
            course = self.course_database["st_andrews"]
            return f"**St. Andrews Links (Old Course):**\n\n• **Location:** {course['location']}\n• **Par/Yardage:** {course['par']}, {course['yardage']} yards\n• **Signature Holes:** {', '.join(course['signature_holes'])}\n• **Key Features:** {', '.join(course['key_features'])}\n• **Playing Tips:** {', '.join(course['playing_tips'])}\n\n🏴󠁧󠁢󠁳󠁣󠁴󠁿 **Historic:** {course['notable']}\n\n💡 **Links Golf:** Embrace the ground game and expect the unexpected!"
        
        else:
            return "I have detailed information about Augusta National, Pebble Beach, and St. Andrews. Which course would you like to know about?"
    
    def _answer_ball_flight_question(self, question: str) -> str:
        """Answer questions about ball flight and shot shaping"""
        
        ball_flight = self.golf_knowledge["advanced_concepts"]["ball_flight_laws"]
        
        if "draw" in question:
            return f"**Draw Shot:**\n{ball_flight['draw']}\n\n**How to hit a draw:**\n• Aim slightly right of target\n• Close clubface slightly at address\n• Swing along your body line\n• Ball will curve right to left\n\n💡 **Best for:** Getting around trees, adding roll, playing in crosswind"
        
        elif "fade" in question:
            return f"**Fade Shot:**\n{ball_flight['fade']}\n\n**How to hit a fade:**\n• Aim slightly left of target\n• Open clubface slightly at address\n• Swing along your body line\n• Ball will curve left to right\n\n💡 **Best for:** Tight fairways, firm greens, controlling distance"
        
        elif "slice" in question:
            return f"**Slice (Problem Shot):**\n{ball_flight['slice']}\n\n**How to fix a slice:**\n• Strengthen your grip\n• Close your stance slightly\n• Practice inside-out swing path\n• Check ball position (not too far forward)\n\n🔧 **Practice drill:** Place alignment stick outside ball to encourage inside-out swing"
        
        elif "hook" in question:
            return f"**Hook (Problem Shot):**\n{ball_flight['hook']}\n\n**How to fix a hook:**\n• Weaken your grip slightly\n• Open your stance slightly\n• Feel like you're holding off the release\n• Check ball position (not too far back)\n\n🔧 **Practice drill:** Try to hit fades on the range to feel the opposite sensation"
        
        elif "straight" in question:
            return f"**Straight Shot:**\n{ball_flight['straight']}\n\n**How to hit it straight:**\n• Square clubface at impact\n• Swing path matches clubface angle\n• Neutral grip and setup\n• Consistent tempo and timing\n\n💡 **Reality check:** Even pros don't hit it perfectly straight - small curves are normal!"
        
        else:
            return "**Ball Flight Basics:**\n\n• **Draw:** Right to left curve (controlled)\n• **Fade:** Left to right curve (controlled)\n• **Slice:** Excessive left to right (usually unwanted)\n• **Hook:** Excessive right to left (usually unwanted)\n• **Straight:** Minimal curve (hardest to achieve)\n\nWhich shot shape would you like to learn more about?"
    
    def _is_club_selection_question(self, question: str) -> bool:
        """Check if question is about club selection or comparison"""
        patterns = [
            r'\d{2,3}?\s*(?:degree|°)', # "52 degree" or "58°"
            r'vs|versus|or|better',     # comparison words
            r'wedge.*wedge',            # "wedge vs wedge"
            r'should i use|what club|which club',
            r'hybrid instead|when should i use|should i chip or pitch',
            r'150.yard|into the wind'
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
        
        # Handle single club questions with conditions
        if yardage:
            return self._recommend_club_for_distance(yardage, question)
        
        # Handle hybrid vs iron question
        if "hybrid instead" in question or "when should i use" in question:
            return "**Hybrid vs Long Iron:**\n\n**Use Hybrid When:**\n• From rough or thick lies\n• Need higher ball flight\n• Want more forgiveness\n• Longer carry distance needed\n• Playing from fairway bunkers\n\n**Use Long Iron When:**\n• Playing in windy conditions\n• Need lower ball flight\n• Better at controlling trajectory\n• Prefer the feel of irons\n\n💡 **Most golfers** benefit from hybrids for 3, 4, and 5-iron distances!"
        
        # Handle chip vs pitch decision  
        if "chip or pitch" in question:
            return "**Chip vs Pitch from 30 Yards:**\n\n**Chip (Lower trajectory):**\n• Pin is back of green\n• Uphill lie to pin\n• Hard, fast greens\n• More room to land and roll\n• Use 8-iron to gap wedge\n\n**Pitch (Higher trajectory):**\n• Pin is front of green\n• Downhill lie to pin\n• Soft greens that hold\n• Need to carry hazard/rough\n• Use sand or lob wedge\n\n🎯 **General rule:** Chip when you can, pitch when you must!"
        
        # Handle wind conditions with yardage
        if "150" in question and "wind" in question:
            return "**150 Yards Into the Wind:**\n\n**Club Selection:**\n• Normal 150 club: 7-iron\n• Into wind: 5 or 6-iron (take 1-2 more clubs)\n• Keep ball lower to reduce wind effect\n\n**Strategy:**\n• Swing easier with more club\n• Ball position slightly back\n• Focus on solid contact\n• Aim for center of green\n\n💨 **Wind rule:** Light wind = 1 club, strong wind = 2 clubs more!"
        
        # General club selection advice
        if "wedge" in question:
            return self._wedge_selection_advice()
        
        # Fallback for club selection
        return "**Club Selection Help:**\n\nI can help you choose the right club! Tell me:\n• Distance to target\n• Wind conditions\n• Lie (fairway, rough, etc.)\n• Pin position\n• Green conditions\n\nOr ask about specific situations like 'hybrid vs long iron' or 'chip vs pitch from 30 yards'!"
    
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
    
    def _is_swing_analysis_question(self, question: str) -> bool:
        """Check if question is about detailed swing analysis"""
        swing_analysis_words = ["spine angle", "early extension", "power", "tempo", "rhythm", 
                               "frame by frame", "analyze", "losing power", "maintain",
                               "early extending", "what's wrong with my swing", "swing plane",
                               "ideal swing plane", "7-iron", "am i early extending", "slicing"]
        return any(phrase in question for phrase in swing_analysis_words)
    
    def _answer_swing_analysis_question(self, question: str) -> str:
        """Handle detailed swing analysis questions"""
        
        if "spine angle" in question:
            flaw = self.golf_knowledge["premium_swing_analysis"]["swing_flaws"]["spine_angle"]
            return f"**Maintaining Spine Angle:**\n\n**Common Cause:** {flaw['cause']}\n\n**Fixes:**\n" + "\n".join([f"• {fix}" for fix in flaw['fixes']]) + f"\n\n**Practice Drills:**\n" + "\n".join([f"• {drill}" for drill in flaw['drills']]) + f"\n\n**Impact on Game:** {flaw['impact']}"
        
        elif "early extension" in question or "early extending" in question:
            flaw = self.golf_knowledge["premium_swing_analysis"]["swing_flaws"]["early_extension"]
            return f"**Early Extension Fix:**\n\n**What it is:** {flaw['cause']}\n\n**How to Fix:**\n" + "\n".join([f"• {fix}" for fix in flaw['fixes']]) + f"\n\n**Key Drills:**\n" + "\n".join([f"• {drill}" for drill in flaw['drills']]) + f"\n\n**Why it matters:** {flaw['impact']}"
        
        elif "power" in question and ("losing" in question or "loss" in question):
            flaw = self.golf_knowledge["premium_swing_analysis"]["swing_flaws"]["power_loss"]
            return f"**Increasing Swing Power:**\n\n**Common Causes:** {flaw['cause']}\n\n**Solutions:**\n" + "\n".join([f"• {fix}" for fix in flaw['fixes']]) + f"\n\n**Power Drills:**\n" + "\n".join([f"• {drill}" for drill in flaw['drills']]) + f"\n\n**Result:** {flaw['impact']}"
        
        elif "tempo" in question or "rhythm" in question:
            tempo = self.golf_knowledge["premium_swing_analysis"]["tempo_rhythm"]
            return f"**Improving Tempo & Rhythm:**\n\n**Ideal Ratio:** {tempo['ideal_ratio']}\n\n**Practice Drills:**\n" + "\n".join([f"• {drill}" for drill in tempo['drills']]) + f"\n\n**Benefits:** {tempo['benefits']}\n\n**Common Issues:** {tempo['common_issues']}"
        
        elif "ideal swing plane" in question or "7-iron" in question:
            return "**7-Iron Swing Plane:**\n\nIdeal swing plane for 7-iron is approximately 60-64° from horizontal (or 26-30° from vertical).\n\n**Key Points:**\n• More upright than driver (which is ~50-55°)\n• Should match your height and arm length\n• Steeper plane helps with ball-first contact\n• Practice with alignment sticks for visual feedback\n\n💡 **Remember:** Your natural swing plane is best - don't force an unnatural position!"
        
        elif "am i early extending" in question:
            return "**Early Extension Check:**\n\nSigns you might be early extending:\n• Loss of spine angle during downswing\n• Hips thrust toward ball\n• Standing up through impact\n• Inconsistent ball contact\n\n**Video check:** Record from down-the-line view and see if your belt buckle moves toward the ball during downswing.\n\n**Quick fix:** Practice the wall drill - setup with your butt against a wall and swing without losing contact!"
        
        elif ("what's wrong with my swing" in question and "slice" in question) or ("slicing" in question):
            flaw = self.golf_knowledge["premium_swing_analysis"]["swing_flaws"]["slice"]
            return f"**Fixing Your Slice:**\n\n**Root Cause:** {flaw['cause']}\n\n**Step-by-Step Fix:**\n" + "\n".join([f"{i+1}. {fix}" for i, fix in enumerate(flaw['fixes'])]) + f"\n\n**Practice Drills:**\n" + "\n".join([f"• {drill}" for drill in flaw['drills']]) + f"\n\n**Why it matters:** {flaw['impact']}\n\n🎯 **Start with grip** - this fixes 70% of slices!"
        
        elif "frame" in question and "analyze" in question:
            return "**Frame-by-Frame Analysis Tips:**\n\n• **Setup:** Check grip, stance, ball position, alignment\n• **Takeaway:** One-piece takeaway, maintain triangle\n• **Top:** Full shoulder turn, maintain spine angle\n• **Transition:** Hips start first, maintain lag\n• **Impact:** Weight forward, hands ahead of ball\n• **Follow-through:** Full finish, balanced\n\n📱 **Use slow-motion video** to identify specific positions and compare to ideal swing!"
        
        return "I can help analyze specific swing issues! Ask me about spine angle, early extension, power loss, tempo, or request frame-by-frame analysis tips."
    
    def _is_data_interpretation_question(self, question: str) -> bool:
        """Check if question is about launch monitor data or stats"""
        data_words = ["launch monitor", "numbers", "spin rate", "smash factor", "launch angle", 
                     "ball speed", "club speed", "carry distance", "data", "mean",
                     "launch monitor numbers mean", "what do my", "numbers mean"]
        return any(phrase in question for phrase in data_words)
    
    def _answer_data_interpretation_question(self, question: str) -> str:
        """Handle launch monitor and data interpretation questions"""
        
        launch_data = self.golf_knowledge["premium_swing_analysis"]["launch_monitor_interpretation"]
        
        if "smash factor" in question:
            return f"**Smash Factor Explained:**\n\n{launch_data['smash_factor']}\n\n**What affects it:**\n• Center contact (most important)\n• Angle of attack\n• Dynamic loft\n• Club condition\n\n**Improvement tips:**\n• Focus on center contact\n• Get fitted for proper specs\n• Practice with impact tape"
        
        elif "spin rate" in question:
            return f"**Spin Rate Impact:**\n\n{launch_data['spin_rate']}\n\n**Driver spin rates:**\n• <2000 RPM: May not carry enough\n• 2000-2800 RPM: Optimal range\n• >3000 RPM: Significant distance loss\n\n**How to optimize:**\n• Improve attack angle (+2° to +5° up)\n• Check equipment (shaft, loft)\n• Work on impact position"
        
        elif "launch angle" in question:
            return f"**Launch Angle Optimization:**\n\n{launch_data['launch_angle']}\n\n**By swing speed:**\n• <90 mph: 12-14° optimal\n• 90-100 mph: 10-13° optimal\n• >100 mph: 9-12° optimal\n\n**How to adjust:**\n• Tee height\n• Ball position\n• Attack angle\n• Driver loft selection"
        
        elif "numbers" in question and "mean" in question:
            return f"**Key Launch Monitor Numbers:**\n\n" + "\n".join([f"**{key.replace('_', ' ').title()}:** {value}" for key, value in launch_data.items()]) + "\n\n💡 **Focus on:** Smash factor first (contact), then optimize launch and spin for your swing speed!"
        
        return "**Launch Monitor Basics:**\nI can explain club speed, ball speed, smash factor, launch angle, spin rate, attack angle, and more! What specific numbers would you like help interpreting?"
    
    def _is_practice_question(self, question: str) -> bool:
        """Check if question is about practice routines or drills"""
        practice_words = ["practice", "routine", "drill", "session", "warmup", "warm up", 
                         "30 minute", "weekly", "improve", "putting drill", "practice routine",
                         "short game practice", "18 handicapper", "build a", "pace control"]
        return any(phrase in question for phrase in practice_words)
    
    def _answer_practice_question(self, question: str) -> str:
        """Handle practice routine and drill questions"""
        
        routines = self.golf_knowledge["practice_routines"]
        
        if (("weekly" in question and "18" in question) or "practice routine for an 18 handicapper" in question):
            weekly = routines["weekly_18_handicap"]
            return f"**Weekly Practice Routine (18 Handicap):**\n\n" + "\n".join([f"**{day.title()}:** {activity}" for day, activity in weekly.items()]) + "\n\n💡 **Key:** Focus on short game 60% of practice time - that's where you'll see the biggest score improvement!"
        
        elif (("30 minute" in question and "short game" in question) or "build a 30-minute short game" in question):
            short_game = routines["30_minute_short_game"]
            return f"**30-Minute Short Game Session:**\n\n" + "\n".join([f"**{time}:** {activity}" for time, activity in short_game.items()]) + "\n\n🎯 **Focus:** Quality over quantity - make each rep count!"
        
        elif "putting" in question and ("drill" in question or "pace" in question):
            putting = routines["putting_drills"]
            return f"**Putting Drills for Better Pace:**\n\n" + "\n".join([f"**{drill.replace('_', ' ').title()}:** {description}" for drill, description in putting.items()]) + "\n\n⛳ **Remember:** Speed control is more important than line - focus on distance first!"
        
        elif "warmup" in question or "warm up" in question:
            warmup = routines["warmup_routine"]
            return f"**Pre-Round Warmup Routine:**\n\n" + "\n".join([f"**{time}:** {activity}" for time, activity in warmup.items()]) + "\n\n🏌️ **Goal:** Get loose, find rhythm, build confidence - not perfect your swing!"
        
        return "**Practice Options:**\n\n• Weekly practice routine for 18-handicappers\n• 30-minute short game sessions\n• Putting drills for pace control\n• Pre-round warmup routines\n\nWhat type of practice schedule would you like help with?"
    
    def _is_fitness_question(self, question: str) -> bool:
        """Check if question is about golf fitness or injury prevention"""
        fitness_words = ["stretch", "flexibility", "strength", "fitness", "workout", "exercise", 
                        "core", "rotation", "back pain", "injury", "shoulder turn", "mobility",
                        "stretches help", "strengthen my core", "exercises reduce", "improve my shoulder"]
        return any(phrase in question for phrase in fitness_words)
    
    def _answer_fitness_question(self, question: str) -> str:
        """Handle golf fitness and injury prevention questions"""
        
        fitness = self.golf_knowledge["fitness_golf"]
        
        if "shoulder turn" in question or "flexibility" in question:
            flexibility = fitness["flexibility"]
            return f"**Improving Shoulder Turn & Flexibility:**\n\n**Shoulder Turn Exercises:**\n" + "\n".join([f"• {ex}" for ex in flexibility['shoulder_turn']]) + f"\n\n**Hip Mobility:**\n" + "\n".join([f"• {ex}" for ex in flexibility['hip_mobility']]) + f"\n\n**Rotation Exercises:**\n" + "\n".join([f"• {ex}" for ex in flexibility['rotation']]) + "\n\n🏃 **Do these 3-4x per week** for noticeable improvement in 2-3 weeks!"
        
        elif "core" in question and ("strength" in question or "rotation" in question):
            strength = fitness["strength"]
            return f"**Core Strengthening for Golf:**\n\n**Core Exercises:**\n" + "\n".join([f"• {ex}" for ex in strength['core']]) + f"\n\n**Glute Strengthening:**\n" + "\n".join([f"• {ex}" for ex in strength['glutes']]) + f"\n\n**Swing Speed Training:**\n" + "\n".join([f"• {ex}" for ex in strength['swing_speed']]) + "\n\n💪 **Start with bodyweight** exercises, add resistance as you get stronger!"
        
        elif "back pain" in question:
            injury = fitness["injury_prevention"]
            return f"**Reducing Golf Back Pain:**\n\n**Helpful Exercises:**\n" + "\n".join([f"• {ex}" for ex in injury['back_pain']]) + f"\n\n**Common Causes:** {injury['common_causes']}\n\n**Prevention Strategy:** {injury['prevention']}\n\n⚠️ **See a professional** if pain persists or is severe!"
        
        elif "swing speed" in question:
            speed = fitness["strength"]["swing_speed"]
            return f"**Increasing Swing Speed:**\n\n**Speed Training Exercises:**\n" + "\n".join([f"• {ex}" for ex in speed]) + "\n\n**Additional Tips:**\n• Improve flexibility first\n• Use lighter/heavier club training\n• Focus on proper sequence\n• Strengthen your core and glutes\n\n⚡ **Expect 5-10 mph increase** with dedicated training over 8-12 weeks!"
        
        return "**Golf Fitness Areas:**\n\n• Flexibility for better shoulder turn\n• Core strength for rotation power\n• Injury prevention (especially back)\n• Swing speed development\n\nWhat aspect of golf fitness interests you most?"
    
    def _is_strategy_mental_question(self, question: str) -> bool:
        """Check if question is about course strategy or mental game"""
        strategy_words = ["narrow fairway", "par 5", "water", "strategy", "mental", "pressure", 
                         "focus", "confidence", "manage", "last holes", "bad hole"]
        return any(phrase in question for phrase in strategy_words)
    
    def _answer_strategy_mental_question(self, question: str) -> str:
        """Handle advanced strategy and mental game questions"""
        
        strategy = self.golf_knowledge["advanced_strategy"]
        
        if "narrow fairway" in question:
            return f"**Narrow Fairway Strategy:**\n\n{strategy['narrow_fairway']}\n\n**Specific Tips:**\n• Use 3-wood or hybrid off tee\n• Pick intermediate target (not just fairway)\n• Favor your natural ball flight\n• Better to be in rough than hazard/OB\n\n🎯 **Remember:** Bogey from fairway beats double from trees!"
        
        elif "par 5" in question and "water" in question:
            return f"**Par 5 with Water Strategy:**\n\n{strategy['par_5_water']}\n\n**Decision Matrix:**\n• Can you clear water 8/10 times? Go for it\n• Less than 8/10? Lay up to 100-yard comfort zone\n• Consider pin position and course conditions\n• Risk vs reward: birdie chance vs disaster hole\n\n💡 **Smart play:** Take your medicine and make par!"
        
        elif "pressure" in question or "last holes" in question:
            return f"**Handling Pressure:**\n\n{strategy['pressure_situations']}\n\n**Pressure Techniques:**\n" + "\n".join([f"• {technique}" for technique in strategy['mental_game']['focus_techniques']]) + "\n\n**On final holes:**\n• Play within yourself\n• Don't change strategy that got you there\n• Accept that nerves are normal\n• Focus on process, not score"
        
        elif "mental" in question and "focus" in question:
            mental = strategy["mental_game"]
            return f"**Staying Mentally Focused:**\n\n**Focus Techniques:**\n" + "\n".join([f"• {technique}" for technique in mental['focus_techniques']]) + f"\n\n**Building Confidence:** {mental['confidence_building']}\n\n🧠 **Key:** Control what you can control - your routine, breathing, and commitment to each shot!"
        
        elif "bad hole" in question:
            mental = strategy["mental_game"]
            return f"**Recovering from Bad Holes:**\n\n{mental['bad_hole_recovery']}\n\n**Reset Strategies:**\n• Take 3 deep breaths\n• Remember: one hole doesn't define the round\n• Focus on immediate next shot\n• Use positive self-talk\n• Stick to your game plan\n\n💪 **Champions bounce back** - use adversity to fuel your comeback!"
        
        return "**Strategy & Mental Areas:**\n\n• Course management (narrow fairways, hazards)\n• Pressure situation handling\n• Mental focus techniques\n• Confidence building\n• Bad hole recovery\n\nWhat specific situation would you like help with?"
    
    def _is_stats_question(self, question: str) -> bool:
        """Check if question is about statistics or handicap improvement"""
        stats_words = ["handicap", "stats", "statistics", "gir", "greens in regulation", 
                      "lower", "improve", "track", "data", "percentage"]
        return any(phrase in question for phrase in stats_words)
    
    def _answer_stats_question(self, question: str) -> str:
        """Handle statistics and improvement tracking questions"""
        
        stats = self.golf_knowledge["statistics_improvement"]
        
        if "handicap" in question and "lower" in question:
            improvement = stats["handicap_improvement"]
            return f"**Lowering Your Handicap:**\n\n**18 to 12 handicap:** {improvement['18_to_12']}\n\n**12 to 6 handicap:** {improvement['12_to_6']}\n\n**6 to scratch:** {improvement['6_to_scratch']}\n\n📊 **Track your progress** with apps like Arccos or Shot Scope to identify exactly what to work on!"
        
        elif "gir" in question or "greens in regulation" in question:
            key_stats = stats["key_stats"]
            return f"**Greens in Regulation (GIR):**\n\n{key_stats['gir']}\n\n**Improvement Strategy:**\n• Focus on approach shot accuracy\n• Take enough club (better long than short)\n• Aim for center of green, not pins\n• Improve iron contact and distance control\n\n🎯 **Reality check:** Even scratch golfers miss 1/3 of greens!"
        
        elif "stats" in question and ("based on" in question or "work on" in question):
            key_stats = stats["key_stats"]
            return f"**Key Golf Statistics to Track:**\n\n" + "\n".join([f"**{stat.upper()}:** {description}" for stat, description in key_stats.items()]) + f"\n\n**Priority Order:**\n1. Putting (biggest impact on score)\n2. Short game (up and down %)\n3. GIR (approach shot accuracy)\n4. Driving accuracy\n\n📱 **Use:** {stats['tracking_apps']}"
        
        elif "work on first" in question or "should I work on" in question:
            return "**Priority Areas by Handicap:**\n\n**20+ handicap:** Short game and course management\n**15-20 handicap:** Putting consistency and eliminating big numbers\n**10-15 handicap:** Iron accuracy and approach shots\n**5-10 handicap:** Mental game and fine-tuning\n**0-5 handicap:** Tournament experience and pressure situations\n\n🎯 **General rule:** Work on short game first - biggest bang for your buck!"
        
        return "**Statistics Help Available:**\n\n• Understanding key golf stats (GIR, FIR, putts per round)\n• Handicap improvement strategies\n• Stat tracking and analysis\n• Priority areas for improvement\n\nWhat specific stats or improvement area interests you?"
    
    def _is_equipment_fitting_question(self, question: str) -> bool:
        """Check if question is about equipment fitting or advanced gear questions"""
        equipment_words = ["fitting", "fitted", "shaft", "flex", "blade", "cavity", "regrip", 
                          "bounce", "lie angle", "swing speed", "off the rack"]
        return any(phrase in question for phrase in equipment_words)
    
    def _answer_equipment_fitting_question(self, question: str) -> str:
        """Handle advanced equipment and fitting questions"""
        
        equipment = self.golf_knowledge["equipment_advanced"]
        
        if "fitting" in question or "fitted" in question:
            fitting = equipment["club_fitting"]
            return f"**Club Fitting Benefits:**\n\n**Potential Gains:** {fitting['benefits']}\n\n**Key Measurements:** {fitting['key_measurements']}\n\n**Fitting Process:** {fitting['fitting_process']}\n\n**Investment:** {fitting['cost_benefit']}\n\n✅ **Worth it if:** You're serious about improvement and play regularly!"
        
        elif "shaft" in question and "flex" in question:
            shaft = equipment["shaft_flex"]
            return f"**Shaft Flex Guide:**\n\n{shaft['guide']}\n\n**Why it matters:** {shaft['fitting_importance']}\n\n**Testing your speed:** {shaft['swing_speed_test']}\n\n**Signs of wrong flex:**\n• Stiff flex in regular player: Low, left shots\n• Regular flex in fast player: High, right shots\n\n🏌️ **Get swing speed tested** for proper fitting!"
        
        elif "blade" in question and "cavity" in question:
            irons = equipment["iron_types"]
            return f"**Iron Type Comparison:**\n\n**Blades:** {irons['blades']}\n\n**Cavity Back:** {irons['cavity_back']}\n\n**Game Improvement:** {irons['game_improvement']}\n\n**Choosing:**\n• 15+ handicap: Game improvement\n• 8-15 handicap: Cavity back\n• <8 handicap: Consider blades\n\n💡 **Most golfers** benefit from cavity backs or game improvement irons!"
        
        elif "regrip" in question:
            return f"**Regripping Schedule:**\n\n{equipment['regripping']}\n\n**Signs you need new grips:**\n• Slippery when wet\n• Hard and shiny surface\n• Visible wear patterns\n• Hands hurt after playing\n\n**Benefits:**\n• Better feel and control\n• Consistent hand pressure\n• Improved confidence\n\n🔧 **Cost:** $5-15 per grip plus installation"
        
        elif "bounce" in question:
            return "**Wedge Bounce Guide:**\n\n**Low Bounce (4-8°):**\n• Firm conditions\n• Tight lies\n• Steep angle of attack\n• Links-style courses\n\n**High Bounce (12°+):**\n• Soft conditions\n• Fluffy sand\n• Shallow angle of attack\n• Parkland courses\n\n**Medium Bounce (8-12°):**\n• Most versatile option\n• Average conditions\n• Good all-around choice\n\n💡 **When in doubt,** choose medium bounce for versatility!"
        
        return "**Equipment & Fitting Topics:**\n\n• Club fitting benefits and process\n• Shaft flex selection\n• Iron types (blade vs cavity back)\n• Regripping schedule\n• Wedge bounce selection\n\nWhat equipment question can I help with?"
    
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
        """Enhanced general golf response with premium features"""
        greeting = random.choice(self.greeting_responses)
        
        return (f"{greeting}\n\n"
                "⭐ **PREMIUM FEATURES** ⭐\n\n"
                "🏌️ **Swing Analysis:** Frame-by-frame feedback, power loss fixes, tempo drills\n"
                "📊 **Data Interpretation:** Launch monitor numbers, spin rate, smash factor\n"
                "🎯 **Club Selection:** Distance recommendations, wedge comparisons, fitting advice\n"
                "💪 **Practice & Fitness:** Weekly routines, golf-specific workouts, injury prevention\n"
                "🧠 **Strategy & Mental:** Course management, pressure situations, confidence building\n"
                "📈 **Stats & Improvement:** Handicap lowering, tracking priorities, improvement plans\n"
                "🏆 **Pro Knowledge:** Tournament history, player analysis, course strategies\n"
                "⚖️ **Rules & Equipment:** Advanced fitting, shaft selection, equipment optimization\n"
                "🌤️ **Playing Conditions:** Weather adjustments, course-specific tips\n\n"
                "💬 **Ask me anything like:**\n"
                "• 'What's wrong with my swing if I keep slicing?'\n"
                "• 'What do my launch monitor numbers mean?'\n"
                "• 'What's a good practice routine for an 18 handicapper?'\n"
                "• 'How can I stay focused under pressure?'\n\n"
                "What aspect of your game would you like to improve today?")

def main():
    """Test CaddieChat Pro with Premium Questions"""
    chatbot = CaddieChat()
    
    # Premium test questions covering all categories
    test_questions = [
        # Swing & Technique Analysis
        "What's wrong with my swing if I keep slicing the ball?",
        "How can I fix a hook in my drive?",
        "What's the ideal swing plane for a 7-iron?",
        "How do I maintain spine angle throughout my swing?",
        "Am I early extending in my swing?",
        "Why am I losing power in my downswing?",
        
        # Club & Shot Selection
        "What club should I use for a 150-yard shot into the wind?",
        "When should I use a hybrid instead of a long iron?",
        "Should I chip or pitch from 30 yards out?",
        
        # Data & Stats Interpretation
        "What do my launch monitor numbers mean?",
        "What's a good greens in regulation percentage?",
        "How can I lower my handicap using my stats?",
        
        # Practice Planning & Drills
        "What's a good weekly practice routine for an 18 handicapper?",
        "Can you build a 30-minute short game practice session?",
        "What putting drills improve pace control?",
        
        # Course Strategy & Mental Game
        "How do I manage a narrow fairway tee shot?",
        "What's the best strategy on a par 5 with water in front of the green?",
        "How can I stay mentally focused after a bad hole?",
        
        # Fitness & Flexibility
        "What stretches help improve my shoulder turn?",
        "How can I strengthen my core for better rotation?",
        "What exercises reduce back pain after a round?",
        
        # Equipment & Gear
        "Should I get fitted for clubs or buy off the rack?",
        "What shaft flex is right for my swing speed?",
        "What's the difference between a blade and a cavity-back iron?"
    ]
    
    print("🏌️ CaddieChat Pro - Premium Golf Chatbot Test\n" + "="*60)
    
    for question in test_questions:
        print(f"\n🔹 Q: {question}")
        answer = chatbot.answer_question(question)
        print(f"🔸 A: {answer}")
        print("-" * 100)

if __name__ == "__main__":
    main()
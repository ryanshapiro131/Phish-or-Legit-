class_name EmailData
 
var sender: String
var subject: String
var body: String
var is_phishing: bool
var damage: int
var reward: int
var difficulty: int = 1  # 1–4: sets salary reward when handled correctly ($25 / $50 / $75 / $100)
var icon: String = "Adam_16x16.png"  # default to unknown

extends Label



@onready var inbox = %Inbox
@onready var incorrect = %Incorrect


# Called when the node enters the scene tree for the first time.
func _ready():
	inbox.text = str("Total Emails Completed: ", (GameManager.correct_emails + GameManager.incorrect_emails))
	incorrect.text = str("Incorrect Emails: ", GameManager.incorrect_emails)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	inbox.text = str("Total Emails Completed: ", (GameManager.correct_emails + GameManager.incorrect_emails))
	incorrect.text = str("Incorrect Emails: ", GameManager.incorrect_emails)
	
	

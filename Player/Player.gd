extends KinematicBody2D

const PlayerHurtSound = preload("res://Player/PlayerHurtSound.tscn")

export var ACCELERATION = 500
export var MAX_SPEED = 80
export var ROLL_SPEED = 100
export var FRICTION = 500

enum {
	MOVE,
	ROLL,
	ATTACK
}

var state = MOVE
var velocity = Vector2.ZERO
var roll_vector = Vector2.DOWN
var stats = PlayerStats

# NPC as DialogNPC (class from baseNpc)
var NPC : DialogNPC
var isInDialog : bool = false
var DialogNode

onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get('parameters/playback')
onready var swordHitbox = $HitboxPivot/SwordHitbox
onready var hurtbox = $Hurtbox
onready var blinkAnimationPlayer = $BlinkAnimationPlayer

func _ready():
	randomize()
	stats.connect("no_health", self, "queue_free")
	animationTree.active = true
	swordHitbox.knockback_vector = roll_vector

func _physics_process(delta):
	match state:
		MOVE:
			move_state(delta)
		ROLL:
			roll_state()
		ATTACK:
			attack_state()
	
func move_state(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()

	if input_vector != Vector2.ZERO:
		roll_vector = input_vector
		swordHitbox.knockback_vector = input_vector
		animationTree.set('parameters/Idle/blend_position', input_vector)
		animationTree.set('parameters/Run/blend_position', input_vector)
		animationTree.set('parameters/Attack/blend_position', input_vector)
		animationTree.set('parameters/Roll/blend_position', input_vector)
		animationState.travel("Run")
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	else:
		animationState.travel('Idle')
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move()
	if Input.is_action_just_pressed("attack"):
		state=ATTACK
	if Input.is_action_just_pressed("roll"):
		state=ROLL

func attack_state():
	velocity = Vector2.ZERO
	animationState.travel('Attack')

func roll_state():
	velocity = roll_vector*ROLL_SPEED
	animationState.travel('Roll')
	move()

func move():
	velocity = move_and_slide(velocity)

func attack_animation_finished():
	state=MOVE

func roll_animation_finished():
	state=MOVE
	velocity = Vector2.ZERO

func _on_Hurtbox_area_entered(area):
	stats.health -= area.damage
	hurtbox.start_invincibility(0.6)
	hurtbox.create_hit_effect()
	var playerHurtSound = PlayerHurtSound.instance()
	get_tree().current_scene.add_child(playerHurtSound)

func _on_Hurtbox_invincibility_started():
	blinkAnimationPlayer.play("Start")

func _on_Hurtbox_invincibility_ended():
	blinkAnimationPlayer.play("Stop")

func _input(event):
	if event.is_action("action"):
		print("action input")
		handle_action_input();

func handle_action_input():
	if get_node_or_null("DialogNode") == null:
		if NPC and not isInDialog:
			get_tree().paused = true
			var DialogNode = Dialogic.start(NPC.DialogueTimelineName)
			print("dialog: ", NPC.DialogueTimelineName)
			DialogNode.pause_mode = Node.PAUSE_MODE_PROCESS
			DialogNode.connect("timeline_end", self, "_onTimelineEnded")
			get_tree().current_scene.add_child(DialogNode)
			isInDialog = true;

func _onTimelineEnded(_timeline_name):
	get_tree().paused = false
	isInDialog = false
	

func _on_InteractionArea_body_entered(body):
	NPC = body as DialogNPC;
	print(NPC)

func _on_InteractionArea_body_exited(body):
	NPC = body as DialogNPC;

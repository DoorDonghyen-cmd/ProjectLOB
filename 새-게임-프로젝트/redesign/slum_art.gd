extends RefCounted
## Atlas polygons separate neighboring poses without altering generated source art.
## Coordinates and planted feet were registered from the output, not the requested grid.
const TEXTURES := {
	"slum_thief":preload("res://assets/art/slum_20261021/thief_states.png"),
	"slum_plate":preload("res://assets/art/slum_20261021/plate_states.png"),
	"slum_battery":preload("res://assets/art/slum_20261021/battery_states.png"),
	"slum_gunner":preload("res://assets/art/slum_20261021/gunner_states.png"),
	"slum_leader":preload("res://assets/art/slum_20261021/leader_states.png"),
}
const REGISTRATION := {
	"slum_thief":{"scale":0.135,"height":112.0,"feet":[Vector2(317,924),Vector2(727,924),Vector2(1285,924)],
		"polygons":[[0,180,512,180,512,980,0,980],[512,180,1000,180,1000,600,1018,600,1018,980,512,980],[1000,80,1536,80,1536,980,1018,980,1018,600,1000,600]]},
	"slum_plate":{"scale":0.15,"height":132.0,"feet":[Vector2(332,924),Vector2(748,924),Vector2(1295,924)],
		"polygons":[[0,200,512,200,512,970,0,970],[512,200,1024,200,1024,600,1080,600,1080,970,512,970],[1024,80,1536,80,1536,970,1080,970,1080,600,1024,600]]},
	"slum_battery":{"scale":0.14,"height":90.0,"feet":[Vector2(275,902),Vector2(713,902),Vector2(1327,902)],
		"polygons":[[0,220,460,220,460,960,0,960],[460,220,890,220,890,960,460,960],[890,280,1536,280,1536,960,890,960]]},
	"slum_gunner":{"scale":0.15,"height":89.0,"feet":[Vector2(340,877),Vector2(825,877),Vector2(1310,877)],
		"polygons":[[0,240,460,240,460,600,510,600,510,940,0,940],[460,240,1018,240,1018,940,510,940,510,600,460,600],[1018,240,1536,240,1536,940,1018,940]]},
	"slum_leader":{"scale":0.15,"height":124.0,"feet":[Vector2(280,924),Vector2(767,924),Vector2(1276,924)],
		"polygons":[[0,220,500,220,500,970,0,970],[500,150,980,150,980,970,500,970],[980,220,1536,220,1536,970,980,970]]},
}

static func pose(species: String, frame: int = 0) -> Dictionary:
	var spec: Dictionary = REGISTRATION[species]
	frame = clampi(frame,0,2)
	var values: Array = spec.polygons[frame]
	var points := PackedVector2Array()
	for i in range(0,values.size(),2): points.append(Vector2(values[i],values[i+1]))
	return {"texture":TEXTURES[species],"uv":points,"anchor":spec.feet[frame],"scale":spec.scale,"height":spec.height}

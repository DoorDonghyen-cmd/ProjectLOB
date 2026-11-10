"""Adapter regressions run the real Godot resolver in isolated temporary saves."""
import copy
import json
from serve_ui_prototype import resolve, WEB, RUNTIME

data = json.loads((WEB / "assets/game_data.json").read_text(encoding="utf-8"))
opening = resolve(dict(action="new",kind="boss",deck=data["combat"]["deck"],parts=["volley_drive","radiator"],seed=731042))
assert opening["ok"]
state = opening["state"]
assert len(state["magazine"]) == 7 and len(state["draw"]) == 3 and state["turns"] == 0
assert sorted(state["magazine"]+state["draw"]) == sorted(data["combat"]["deck"])
print("PASS automatic magazine uses owned deck and current capacity")

def command(action, source=state, **extra):
    result = resolve(dict(action=action, state=source, **extra))
    assert result["ok"], result
    return result

before = copy.deepcopy(state)
preview = command("preview", indices=[1,4])
ejected = command("eject", indices=[1,4])
assert state == before and preview["view"] == ejected["view"]
after = ejected["state"]
assert after["magazine"] == [v for i,v in enumerate(state["magazine"]) if i not in (1,4)]
for key in ("turns","heat","rng_state","target_rng_state","buff","deck","enemies","draw"):
    assert after[key] == state[key], key
assert ejected["view"]["eject_left"] == 0
assert len(after["discard"]) == 2
print("PASS preview and middle ejection preserve order, heat, time, RNG and ownership")

for indices in ([0,0],[0,1,2],[-1],[20]):
    assert not resolve(dict(action="eject",state=state,indices=indices))["ok"]
assert not resolve(dict(action="eject",state=after,indices=[0]))["ok"]
print("PASS duplicate, out-of-range and over-budget ejection rejected atomically")

fired = command("fire")
prediction = opening["view"]["forecast"]
assert fired["state"]["enemies"] == prediction["enemies"]
assert fired["state"]["magazine"] == prediction["remaining"] == state["magazine"][2:]
assert fired["state"]["phase"] == prediction["phase"]
assert fired["state"]["turns"] - state["turns"] == prediction["turns"]
assert fired["state"]["buff"].get("dmg",0) == 3  # charge -> cooling keeps next-attack boost
second = command("fire",fired["state"])
assert second["shots"][0]["math"]["boost"] == 3
print("PASS two-round fire matches Forecast and keeps support boost across actions")

single = command("eject",indices=[4])
shot = command("fire",single["state"])
warm = copy.deepcopy(shot["state"]); warm["heat"] = 8
cooled = command("cool",warm)
assert cooled["state"]["heat"] == 2 and cooled["state"]["turns"] == warm["turns"]+1
assert cooled["state"]["magazine"] == warm["magazine"] and cooled["view"]["eject_left"] == 1
swapped = command("reload",cooled["state"])
pool = cooled["state"]["draw"]+cooled["state"]["magazine"]
assert swapped["state"]["magazine"] == pool[:7] and swapped["state"]["draw"] == pool[7:]
assert swapped["view"]["eject_left"] == 2 and swapped["state"]["turns"] == cooled["state"]["turns"]+2
print("PASS fire/cooling retain ejection allowance; paid exchange cycles reserve and resets it")

hot = copy.deepcopy(state); hot["heat"]=14
overheated = command("fire",hot)
assert len(overheated["shots"]) == 1
assert overheated["state"]["magazine"] == hot["magazine"][1:]
assert overheated["state"]["turns"] == 3 and overheated["state"]["heat"] == 0
print("PASS overheat preserves unfired rounds and costs firing plus two cooling actions")

empty = copy.deepcopy(state)
empty["discard"] = empty["deck"].copy(); empty["magazine"]=[]; empty["draw"]=[]; empty["hand"]=[]
for enemy in empty["enemies"]: enemy["distance"]=100
assert not resolve(dict(action="reload",state=empty))["ok"]
for expected in (3,4):
    result = command("emergency",empty)
    assert result["state"]["turns"]-empty["turns"] == expected
    assert result["state"]["magazine"] == ["basic_p2"]*4
    empty=result["state"]; empty["discard"]+=empty["magazine"]; empty["magazine"]=[]
print("PASS emergency grants actual four basic rounds and escalating 3/4 action costs")

near=copy.deepcopy(state)
near["enemies"][0]["distance"]=1
lost=command("reload",near)
assert lost["state"]["phase"] == "lost" and not lost["state"]["magazine"]
assert not resolve(dict(action="fire",state=lost["state"]))["ok"]
winner=copy.deepcopy(state); winner["magazine"]=["basic_p3"]; winner["enemies"]=winner["enemies"][:1]
winner["enemies"][0].update(hp=1, max_hp=1); winner["enemies"][0]["def"]=0
won=command("fire",winner)
assert won["state"]["phase"] in ("won","reward")
assert not resolve(dict(action="fire",state=won["state"]))["ok"]
print("PASS lethal exchange never refills; terminal states reject further fire")

fixtures={name:{k:v for k,v in value.items() if k!="state"} for name,value in
          dict(opening=opening,preview=preview,ejected=ejected,fired=fired).items()}
(RUNTIME / "client_fixtures.json").write_text(json.dumps(fixtures,ensure_ascii=False),encoding="utf-8")
print("PASS 8 adapter scenarios; UI input and layout checked separately")

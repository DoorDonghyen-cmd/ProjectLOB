extends "res://tests/shop_terminal_live_runner.gd"
var recording:=false
var started:=0
var next_sample:=0
var region:=Rect2i()
var images:Array=[]
var timestamps:Array=[]
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func post_draw() -> void:
	if not recording:return
	var now:=Time.get_ticks_msec()-started
	if now<next_sample:return
	next_sample=now+50
	images.append(root.get_texture().get_image().get_region(region))
	timestamps.append(now)
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/interaction_fx_20261106/"):quit(2);return
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	screen=load("res://redesign/main.tscn").instantiate();root.add_child(screen);await settle()
	await enter_shop(0,"carrier","burst",true);await fixture_offers()
	screen.preferences.data.motion="normal";screen.feedback.configure(screen.preferences.data)
	var before=canonical({"campaign":screen.campaign.s,"combat":screen.model.s,"profile":screen.campaign.profile})
	var expected=Campaign.new();check(expected.restore_state(before),"movie source is a valid isolated state")
	check(expected.buy(0),"movie oracle buys the selected item")
	expected.sync_combat();expected.normalize_for_save()
	var button:Button=field("Buy");var rect:=button.get_global_rect()
	var area:Rect2=rect.merge(field("PartsButton").get_global_rect()).merge(field("ConsoleWallet").get_global_rect()).grow(22)
	region=Rect2i(area).intersection(Rect2i(Vector2i.ZERO,root.size))
	RenderingServer.frame_post_draw.connect(post_draw)
	started=Time.get_ticks_msec();recording=true
	await create_timer(0.10).timeout
	var at:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	var press:=InputEventScreenTouch.new();press.index=0;press.pressed=true;press.position=at
	root.push_input(press,true);await create_timer(0.18).timeout
	check(canonical({"campaign":screen.campaign.s,"combat":screen.model.s,"profile":screen.campaign.profile})==before,"holding the native key never buys early")
	var release:=InputEventScreenTouch.new();release.index=0;release.pressed=false;release.position=at
	root.push_input(release,true);await create_timer(0.55).timeout
	recording=false;RenderingServer.frame_post_draw.disconnect(post_draw)
	check(button.get_global_rect()==rect,"recorded key never scales or moves")
	check(canonical(screen.model.s)==canonical(expected.model.s) and screen.campaign.s.credits==expected.s.credits,"recording preserves exact result/RNG and one payment")
	check(screen.interactions.transactions.size()==1,"one accepted completion in the movie")
	for i in range(images.size()):images[i].save_png(output.path_join("frame_%03d.png"%i))
	FileAccess.open(output.path_join("movie.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"timestamps_ms":timestamps,"region":str(region),"frames":images.size(),"credits_before":before.campaign.credits,"credits_after":screen.campaign.s.credits},"  "))
	screen.free()
	print("INTERACTION FX MOVIE COMPLETE checks=%d failures=%d frames=%d"%[checks,failures,images.size()]);quit(0 if failures==0 else 1)

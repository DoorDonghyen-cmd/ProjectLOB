@tool
extends Control
## One cell per actual heat unit. Forecast data remains owned by the model.
@export var limit: int=12:
 set(value):limit=maxi(1,value);queue_redraw()
@export var current: int=0:
 set(value):current=value;queue_redraw()
@export var peak: int=5:
 set(value):peak=value;queue_redraw()
@export var danger: bool=false:
 set(value):danger=value;queue_redraw()

func _ready()->void:resized.connect(queue_redraw)
func display(heat: int,maximum: int,forecast: int,warning: bool)->void:
 current=heat;limit=maximum;peak=forecast;danger=warning

func _draw()->void:
 var columns: int=floori(size.x/2.0)
 for i in range(limit):
  var x: int=floori(float(i)*columns/limit)*2
  var right: int=floori(float(i+1)*columns/limit)*2-2
  var w: int=maxi(2,right-x)
  var h: int=floori(size.y/2.0)*2
  draw_rect(Rect2(x,0,w,h),Color("02100f"))
  if i<current:
   draw_rect(Rect2(x,0,w,h),Color("ff6f61") if danger else Color("ff9a6a"))
  elif i<peak:
   draw_rect(Rect2(x,0,w,h),Color(0.953,0.812,0.451,0.45))

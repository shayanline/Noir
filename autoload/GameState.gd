extends Node
## The flow and data model: the loaded story, the current act and the current line. It never
## touches the visual tree, Main reads it and drives the view. Stories stay portable data
## (typed Story / Act / Line resources), so telling a tale is writing data, not board code.

signal fx_fired(name: String)

var story: Story
var act_index := 0
var line_index := 0


func load_story(s: Story) -> void:
	story = s
	act_index = 0
	line_index = 0


func acts() -> Array[Act]:
	return story.acts if story else ([] as Array[Act])


func act_count() -> int:
	return acts().size()


func current_act() -> Act:
	var list := acts()
	if act_index < 0 or act_index >= list.size():
		return null
	return list[act_index]


func script_lines() -> Array[Line]:
	var a := current_act()
	return a.lines if a else ([] as Array[Line])


func current_line() -> Line:
	var lines := script_lines()
	if line_index < 0 or line_index >= lines.size():
		return null
	return lines[line_index]


func has_next_line() -> bool:
	return line_index < script_lines().size() - 1


func next_line() -> void:
	line_index += 1


func at_last_act() -> bool:
	return act_index >= act_count() - 1


func go_to_act(idx: int) -> void:
	act_index = clampi(idx, 0, act_count() - 1)
	line_index = 0


func act_titles() -> Array[String]:
	var out: Array[String] = []
	for a in acts():
		out.append(a.title)
	return out


## fired by Main when a line carries fx, so any object on the board can react.
func fire_fx(event: String) -> void:
	fx_fired.emit(event)

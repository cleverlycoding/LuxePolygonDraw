package components;

import components.EditorComponent;
import luxe.Component;
import luxe.Color;

class MatchColorPicker extends EditorComponent {

	var polygon : Polygon;

	override function init() {
		polygon = cast entity;
		polygon.color = Main.instance.picker.pickedColor;
	}
}
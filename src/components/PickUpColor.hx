package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class PickUpColor extends ActivateableComponent {
	override public function activate() {
		var tmp = Main.instance.curPoly().color.clone();
		Main.instance.picker.pickedColor = tmp.toColorHSV();
	}
}

package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class DropColor extends ActivateableComponent {
	override public function activate() {
		Edit.ChangeColor(Main.instance.curPoly(), Main.instance.picker.pickedColor.clone());
	}
}

package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class SwitchToEditMode extends ActivateableComponent {
	override public function activate() {
		trace("edit mode!!!");
		Main.instance.machine.set("edit", Main.instance);
	}
}

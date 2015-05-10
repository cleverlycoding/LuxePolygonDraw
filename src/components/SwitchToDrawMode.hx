package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class SwitchToDrawMode extends ActivateableComponent {
	override public function activate() {
		trace("draw mode!!!");
		Main.instance.machine.set("draw", Main.instance);
	}
}

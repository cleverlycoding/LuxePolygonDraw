package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class ColorModeSwitch extends ActivateableComponent {
	override public function activate() {
		if (Main.instance.machine.current_state.name == "pickcolor") {
			Main.instance.machine.set("draw", Main.instance); //swap to previous state when I know how
		}
		else {
			Main.instance.machine.set("pickcolor", Main.instance);
		}
	}
}

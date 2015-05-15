package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class StartGame extends ActivateableComponent {
	override public function activate() {
		Main.instance.machine.set("play", Main.instance);
	}
}

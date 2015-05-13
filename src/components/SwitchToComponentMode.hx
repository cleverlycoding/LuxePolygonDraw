package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class SwitchToComponentMode extends ActivateableComponent {
	override public function activate() {
		trace("component mode!!!!!");
		Main.instance.machine.set("component", Main.instance);
	}
}

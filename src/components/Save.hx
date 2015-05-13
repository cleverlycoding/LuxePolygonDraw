package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class Save extends ActivateableComponent {
	override public function activate() {
		Main.instance.Save();
	}
}
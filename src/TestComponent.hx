import luxe.Component;
import luxe.Vector;

class TestComponent extends Component {
	public var testMessage = "you've found the right type!";

	override function init() {
		trace("test component created!");
	}

	override function update(dt : Float) {
		trace("update " + dt);
		var v = new Vector(0, 30);
		pos.add(Vector.Multiply(v, dt));
	}

	override function onremoved() {
		trace("test component removed!");
	}
}

package animation;

import luxe.tween.actuators.SimpleActuator;
import luxe.tween.easing.Linear;

class LinearActuator extends SimpleActuator {
	override public function new (target:Dynamic, duration:Float, properties:Dynamic) {
		super(target, duration, properties);
		ease(Linear.easeNone);
	}
}
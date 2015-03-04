package components;
import components.EditorComponent;

import luxe.Component;
import luxe.utils.Maths;
import luxe.Vector;
import luxe.Input;

import Polygon;

class BallControl extends EditorComponent {

	var polygon : Polygon;

	var velocity : Vector = new Vector(0,0);
	var followForce : Float = 300;
	var maxSpeed : Float = 200;
	var maxSpeed_low : Float = 60; //must be a better way to do this (states? a multiplier? a central time controller?)

	var lowGravity : Float = 30;
	var airResistance : Float = 0.6;

	override function init() {
		polygon = cast entity;
	}

	override function update(dt : Float) {
		if (Luxe.input.mousedown(1)) {
			var mouseWorldPos = Luxe.camera.screen_point_to_world(Luxe.screen.cursor.pos);
			var dir = (Vector.Subtract(mouseWorldPos, pos)).normalized;

			velocity.add(dir.multiplyScalar(followForce * dt));

			//air resistance
			velocity.subtract(Vector.Multiply(velocity, airResistance * dt));

			if (velocity.length > maxSpeed) velocity = velocity.normalized.multiplyScalar(maxSpeed);
		}
		else {
			velocity.add(new Vector(0, lowGravity * dt));

			if (velocity.length > maxSpeed) velocity = velocity.normalized.multiplyScalar(maxSpeed_low);
		}

		//move
		pos.add(Vector.Multiply(velocity, dt));
	}

	override function onmouseup(e : MouseEvent) {
		velocity.multiplyScalar(0.3); //slow velocity
	}

	override function onremoved() {
	}
}

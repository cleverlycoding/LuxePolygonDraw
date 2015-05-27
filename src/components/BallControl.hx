package components;
import components.EditorComponent;

import luxe.Component;
import luxe.utils.Maths;
import luxe.Vector;
import luxe.Input;
import luxe.Color;
import luxe.tween.Actuate;

import Polygon;

using utilities.VectorExtender;

class BallControl extends EditorComponent {

	var polygon : Polygon;

	var velocity : Vector = new Vector(0,0);
	var followForce : Float = 300;
	var maxSpeed : Float = 200;
	var maxSpeed_low : Float = 60; //must be a better way to do this (states? a multiplier? a central time controller?)

	var lowGravity : Float = 30;
	var airResistance : Float = 0.6;

	var startScale : Vector;

	override function init() {
		polygon = cast entity;

		entity.events.listen('collision_enter', on_collision_enter);
		entity.events.listen('collision_stay', on_collision_stay);

		startScale = entity.transform.scale.clone();
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

	function on_collision_enter(collision) {
		pos.add(collision.data.separation);

		//bounce backwards
		if (Luxe.input.mousedown(1)) {
			//double bounce power to counteract the force of the pull
			velocity.subtract( Vector.Multiply(collision.data.unitVector, collision.data.unitVector.dot(velocity) * 2 * 2) );
		}
		else {
			velocity.subtract( Vector.Multiply(collision.data.unitVector, collision.data.unitVector.dot(velocity) * 2) );
			velocity.multiplyScalar(0.6); //friction
		}

		//var curScale = entity.transform.scale.clone();
		entity.transform.scale = startScale.clone();

		var shrinkScale = Vector.Subtract(startScale, Vector.Multiply(collision.data.unitVector, startScale.length * 0.3).absolute()); //Vector.Multiply(startScale, 0.7);
		
		Actuate.tween( entity.transform.scale, 0.1, {x: shrinkScale.x, y: shrinkScale.y} )
			.onComplete(function(){
				Actuate.tween( entity.transform.scale, 0.1, {x: startScale.x, y: startScale.y} );
			});
	}

	function on_collision_stay(collision) {
		pos.add(collision.data.separation);
	}
}

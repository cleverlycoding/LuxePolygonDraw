package components;
import components.EditorComponent;
import luxe.Component;

import luxe.tween.Actuate;
import luxe.Vector;

class BounceEffect extends EditorComponent {

	var startScale : Vector;

	override function init() {
		startScale = entity.transform.scale;
		entity.events.listen('collision_enter', on_collision_enter);
	}

	override function update(dt : Float) {
		
	}

	override function onremoved() {
	}

	public function bounce() {
		entity.transform.scale = startScale.clone();

		var shrinkScale = Vector.Multiply(startScale, 0.7);
		
		Actuate.tween( entity.transform.scale, 0.1, {x: shrinkScale.x, y: shrinkScale.y} )
			.onComplete(function(){
				Actuate.tween( entity.transform.scale, 0.1, {x: startScale.x, y: startScale.y} );
			});
	}

	function on_collision_enter(collision) {
		bounce();
	}
}

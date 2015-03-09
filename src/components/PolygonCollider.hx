package components;
import components.EditorComponent;

import luxe.Component;
import luxe.collision.Collision;
import luxe.collision.CollisionData;
import luxe.collision.shapes.Polygon in PolygonCollisionShape;

using ledoux.UtilityBelt.PolylineExtender;

//debug
import luxe.collision.ShapeDrawerLuxe;
import luxe.Color;

typedef PolygonCollision = {
	public var other : PolygonCollider;
	public var data : CollisionData;
}

class PolygonCollider extends EditorComponent {

	public static var ColliderList : Array<PolygonCollider> = [];
	
	var polygon : Polygon;
	public var collisionShape : PolygonCollisionShape;

	var collisions : Array<PolygonCollider> = []; //what colliders have we hit this frame?
	public var hasTestedCollisionsThisFrame (default, set) : Bool;

	//static colliders are not intended to move, so they don't actively test for collisions
	//they wait for active (moving) colliders to hit them instead
	//this should save a lot of processing power
	//NOTE: for now by default I'm making them active since I won't use that many colliders
	@editor(false)
	public var isStatic : Bool;

	//debug
	//var drawer = new ShapeDrawerLuxe();

	override function init() {
		polygon = cast entity;

		collisionShape = polygon.collisionBounds();

		ColliderList.push(this);
	}

	override function update(dt : Float) {
		//update position (not updating the actual shape right now)
		collisionShape.x = polygon.pos.x;
		collisionShape.y = polygon.pos.y;

		//test collisions if you're NOT a static collider
		if (!isStatic) {
			testCollisions();
		}
		hasTestedCollisionsThisFrame = true;

		//drawer.drawPolygon(collisionShape, new Color(255,0,0), true);
	}

	override function onremoved() {
		ColliderList.remove(this);
	}

	function testCollisions() {
		var newCollisions : Array<PolygonCollider> = [];
		
		for (other in ColliderList) { //check all colliders in the world
			//don't collide with yourself 
			//NOR with objects that have already run their tests
			//BUT static objects don't test collisions so they're still fair game
			if (other != this && (!other.hasTestedCollisionsThisFrame || other.isStatic)) { 

				//get collision data
				var results = Collision.test(collisionShape, other.collisionShape);
				//also get the collision data from the other collider's perspective
				var resultsOther = Collision.test(other.collisionShape, collisionShape);
				
				if (results != null) { //there is a collision
					if (collisions.indexOf(other) == -1) { //this collision didn't happen last frame
						//trace("collision_enter");
						entity.events.fire('collision_enter', {other: other, data: results});
						other.entity.events.fire('collision_enter', {other: this, data: resultsOther});
					}
					else { //these polygons collided in the previous frame
						//trace("collision_stay");
						entity.events.fire('collision_stay', {other: other, data: results});
						other.entity.events.fire('collision_stay', {other: this, data: resultsOther});
					}

					newCollisions.push(other);
				}
				else { //there is NOT a collision

					if (collisions.indexOf(other) > -1) { //these polygons collided in the previous frame, but NOT this frame
						//trace("collision_exit");
						entity.events.fire('collision_exit', {other: other, data: null});
						other.entity.events.fire('collision_exit', {other: this, data: null});
					}

				}

			}
		}

		collisions = newCollisions; //update collision list for this frame
	}

	//this is a weird -- yet perhaps elegant -- hack for resetting the hasTestedCollisionsThisFrame flag
	function set_hasTestedCollisionsThisFrame(b : Bool) {
		hasTestedCollisionsThisFrame = b; //set local flag

		for (other in ColliderList) {
			if (!other.hasTestedCollisionsThisFrame) {
				return hasTestedCollisionsThisFrame; //return WITHOUT resetting flags
			}
		}

		//reset all flags to FALSE if all flags are TRUE 
		//(only the last collider should cause this to happen)
		for (other in ColliderList) {
			other.hasTestedCollisionsThisFrame = false;
		}

		return hasTestedCollisionsThisFrame; //return after resetting flags
	}
}

package animation;

import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import luxe.Entity;
import phoenix.Batcher;
import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import luxe.utils.Maths;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPolygon;
import luxe.tween.Actuate;
import luxe.tween.actuators.SimpleActuator;
import luxe.tween.actuators.MotionPathActuator;
import luxe.tween.actuators.GenericActuator;

using ledoux.UtilityBelt.TransformExtender;
using ledoux.UtilityBelt.VectorExtender;
using ledoux.UtilityBelt.PolylineExtender;

using Lambda;

typedef BoneFrameData = {
	public var length : Float;
	public var rotation_z : Float;
}

class Bone extends Visual {

	var length : Float;
	var points : Array<Vector>;
	public var frames : Array<BoneFrameData> = [];
	public var frameIndex (default, set) : Int = 0;
	var isAnimating : Bool;
	
	override public function new(_options : luxe.options.VisualOptions, length : Float, rotation_z : Float) {
		_options.name = "Bone";
		_options.name_unique = true;
		super(_options);

		trace(this.name);

		this.length = length;
		this.rotation_z = rotation_z;

		geometry = new Geometry({
			batcher : _options.batcher,
			primitive_type : PrimitiveType.triangles
		});

		var p0 = new Vector(0, -10);
		var p1 = new Vector(10, 0);
		var p2 = new Vector(-10, 0);
		var p3 = new Vector(0, length);

		points = [p0,p1,p2,p3]; //for collision purposes

		geometry.add(new Vertex(p0));
		geometry.add(new Vertex(p1));
		geometry.add(new Vertex(p2));

		geometry.add(new Vertex(p1));
		geometry.add(new Vertex(p2));
		geometry.add(new Vertex(p3)); //final vertex determines length

		geometry.color = new Color(255,255,255);

		//start keeping track of frames
		if (parent != null) {
			for (i in 0 ... cast(parent).frames.length) { //make sure the bones has the same # of frames as parent
				frames.push({length : this.length, rotation_z : this.rotation_z});
			}
			frameIndex = cast(parent).frameIndex; //make sure bone starts on the same frame as its parent
		}
		else {
			frames.push({length : this.length, rotation_z : this.rotation_z});
			frameIndex = 0;
		}
		
	}

	public function drawEditHandles() {
		
		//get world pos of bone
		var worldPos = worldPos();

		//draw scale handle
		var scaleHandlePos = worldPos.clone().add(transform.up().multiplyScalar(length));
		
		Luxe.draw.rectangle({
			w: 10, h: 10,
			x: scaleHandlePos.x - 5, y: scaleHandlePos.y - 5,
			color : new Color(0,255,0),
			immediate : true,
			batcher : geometry.batchers[0]
		});

		//draw rotation handle
		var rotationHandlePos = worldPos.clone().add(transform.up().multiplyScalar(-40));
		
		Luxe.draw.line({
			p0 : worldPos,
			p1 : rotationHandlePos,
			color : new Color(255,0,255),
			immediate : true,
			batcher : geometry.batchers[0]
		});

		Luxe.draw.ring({
			x : rotationHandlePos.x, y : rotationHandlePos.y,
			r : 15,
			color : new Color(255,0,255),
			immediate : true,
			batcher : geometry.batchers[0]
		});

	}

	public function worldPos() : Vector {
		var worldPos = pos.clone();
		if (transform.parent != null) {
			worldPos = pos.toWorldSpace(transform.parent);
		}
		return worldPos;
	}

	public function collisionShape() : CollisionPolygon {
		var wp = worldPos();
		var worldPoints = points.clone();

		worldPoints = worldPoints.map( 
			function(p) {
				p = p.toWorldSpace(transform);
				p.subtract(wp);
				return p; 
			} 
		);

		return new CollisionPolygon(wp.x, wp.y, worldPoints);
	}

	public function rotationHandleCollisionShape() : CollisionCircle {
		var worldPos = worldPos();
		var rotationHandlePos = worldPos.clone().add(transform.up().multiplyScalar(-40));

		return new CollisionCircle(rotationHandlePos.x, rotationHandlePos.y, 15);
	}

	function set_frameIndex(index : Int) : Int {

		if (index < 0) index = 0; //no negative frames

		if (index >= frames.length) { //make a new frame
			index = frames.length;
			frames.push({length : this.length, rotation_z : this.rotation_z});
		}

		//update child bones
		for (c in children) {
			var b = cast(c, Bone);
			b.frameIndex = index;
		}

		//update frameIndex var
		frameIndex = index;

		//update bone position to match frame
		this.length = frames[index].length; //not using this yet -- will need to keep visuals up to date too
		this.rotation_z = frames[index].rotation_z;

		return frameIndex;
	}

	override function set_rotation_z( _degrees:Float ) : Float {
		super.set_rotation_z(Maths.wrap_angle(_degrees, 0, 360)); //keep rotations b/w 0 and 360 degrees

		if (frames.length > 0 && !isAnimating) frames[frameIndex].rotation_z = rotation_z;

		return _degrees;
	}

	public function animate(timeBetweenFrames : Float) {
		isAnimating = true;

		//animate children
		for (c in children) {
			var b = cast(c, Bone);
			b.animate(timeBetweenFrames);
		}

		//start your own animation
		frameIndex = 0;
		tweenToNextFrame(timeBetweenFrames);

	}

	function tweenToNextFrame(timeBetweenFrames : Float) {
		var nextFrame = frameIndex + 1;

		if (nextFrame < frames.length) {

			//wrap target rotation so that the bone always rotates the correct direction, taking the shortest path
			var endRotZ = Maths.wrap_angle(frames[nextFrame].rotation_z, rotation_z - 180, rotation_z + 180);

			Actuate.tween(this, timeBetweenFrames, {rotation_z: endRotZ}, true, LinearActuator)
				.onComplete(function() {
					frameIndex = nextFrame;
					tweenToNextFrame(timeBetweenFrames);
				});

		}
		else {
			trace("done animating!");
			isAnimating = false;
		}
	}

	//get this bone and ALL sub-bones (breadth first search)
	public function skeleton() : Array<Bone> {
		var skel : Array<Bone> = [];
		var skelSearch : Array<Bone> = [this];

		while (skelSearch.length > 0) {
			var bone = skelSearch[0];

			for (c in bone.children) {
				if (Std.is(c, Bone)) {
                    skelSearch.push(cast c);
                }
			}

			skelSearch.remove(bone);
			skel.push(bone);
		}

		return skel;
	}

	public function closestWorldPoint(otherPoint : Vector) : Vector {
		var a = worldPos();
		var b = worldPos().clone().add(transform.up().multiplyScalar(length));

		return otherPoint.closestPointOnLine( a, b );
	}

	public function endPos() : Vector {
		return worldPos().clone().add(transform.up().multiplyScalar(length));
	}
}
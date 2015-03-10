package animation;

import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import phoenix.Batcher;
import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import luxe.utils.Maths;

using ledoux.UtilityBelt.TransformExtender;
using ledoux.UtilityBelt.VectorExtender;

class Bone extends Visual {
	public static var SkeletonBatcher : Batcher;

	var length : Float;

	public var testRot : Float;
	
	override public function new(_options : luxe.options.VisualOptions, length : Float) {
		super(_options);

		this.length = length;

		geometry = new Geometry({
			batcher : SkeletonBatcher,
			primitive_type : PrimitiveType.triangles
		});

		var p0 = new Vector(0, -10);
		var p1 = new Vector(10, 0);
		var p2 = new Vector(-10, 0);
		var p3 = new Vector(0, length);

		geometry.add(new Vertex(p0));
		geometry.add(new Vertex(p1));
		geometry.add(new Vertex(p2));

		geometry.add(new Vertex(p1));
		geometry.add(new Vertex(p2));
		geometry.add(new Vertex(p3));

		geometry.color = new Color(255,255,255);

		//debug
		testRot = Maths.random_float(5,20);
	}

	public function drawEditHandles() {
		
		var worldPos = pos.clone();
		if (transform.parent != null) {
			worldPos = pos.toWorldSpace(transform.parent);
		}

		//scale handle
		var scaleHandlePos = worldPos.clone().add(transform.up().multiplyScalar(length));
		
		Luxe.draw.rectangle({
			w: 10, h: 10,
			x: scaleHandlePos.x - 5, y: scaleHandlePos.y - 5,
			color : new Color(0,255,0),
			immediate : true,
			batcher : SkeletonBatcher
		});

		//rotation handle
		var rotationHandlePos = worldPos.clone().add(transform.up().multiplyScalar(-40));
		
		Luxe.draw.line({
			p0 : worldPos,
			p1 : rotationHandlePos,
			color : new Color(255,0,255),
			immediate : true,
			batcher : SkeletonBatcher
		});

		Luxe.draw.ring({
			x : rotationHandlePos.x, y : rotationHandlePos.y,
			r : 15,
			color : new Color(255,0,255),
			immediate : true,
			batcher : SkeletonBatcher
		});
	}
}
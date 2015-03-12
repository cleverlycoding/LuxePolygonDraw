package ledoux;

import luxe.Vector;
import luxe.Transform;
import luxe.Matrix;
import luxe.Quaternion;
import luxe.Visual;
import luxe.utils.Maths;
import luxe.collision.shapes.Polygon in PolygonCollisionShape;

using Lambda;
using ledoux.UtilityBelt.VectorExtender;
using ledoux.UtilityBelt.TransformExtender;
using ledoux.UtilityBelt.PolylineExtender;

class VectorExtender {
	static public function distance(pos1:Vector, pos2:Vector) : Float {
		return Vector.Subtract(pos1, pos2).length;
	}

	static public function cross2D(v1:Vector, v2:Vector) : Float {
		return (v1.x * v2.y) - (v1.y * v2.x);
	}

	//these two functions are probably unnecessary
	static public function toLocalSpace(v:Vector, t:Transform) : Vector {
		var localV : Vector;
		localV = v.clone().transform(t.world.matrix.inverse());
		return localV;
	}

	static public function toWorldSpace(v:Vector, t:Transform) : Vector {
		var worldV : Vector;
		worldV = v.clone().transform(t.world.matrix);
		return worldV;
	}

	static public function absolute(v:Vector) : Vector {
		return new Vector(Math.abs(v.x), Math.abs(v.y));
	}

	static public function setFromAngle(v:Vector, radians:Float) : Vector {
		v = new Vector(Math.cos(radians), Math.sin(radians));
		return v;
	}

	static public function tangent2D(v:Vector) : Vector {
		return new Vector(-v.y, v.x);
	}

	static public function closestPointOnLine(v:Vector, a:Vector, b:Vector) : Vector {
		var ab = Vector.Subtract(b, a);
		var av = Vector.Subtract(v, a);

		var d = Maths.clamp(av.dot(ab), 0, ab.length);

		return Vector.Add( a, Vector.Multiply(ab.normalized, d) );
	}
}

class TransformExtender {
	static public function up(t:Transform) {
		var upV = new Vector(0.0, 1.0);
		upV.applyQuaternion(t.rotation);
		
		var parent = t.parent;
		while (parent != null) {
			upV.applyQuaternion(parent.rotation);
			parent = parent.parent;
		}

		return upV;
	}

	static public function right(t:Transform) {
		var rightV = new Vector(1.0, 0.0);
		rightV.applyQuaternion(t.rotation);

		var parent = t.parent;
		while (parent != null) {
			rightV.applyQuaternion(parent.rotation);
			parent = parent.parent;
		}

		return rightV;
	}

	static public function rotate(t:Transform, a:Float) { //rotates right (remember a == radians --- change later?)
		var rot = ( new Quaternion() ).setFromAxisAngle( new Vector(0,0,1), a );
		t.rotation.multiply(rot);
	}

	static public function rotateY(t:Transform, a:Float) { //rotates "inward"
        var rot = ( new Quaternion() ).setFromAxisAngle( new Vector(0,1,0), a );
        t.rotation.multiply(rot);
	}

	static public function setRotationZ(t:Transform, degrees:Float) {
		var rot = ( new Quaternion() ).setFromAxisAngle( new Vector(0,0,1), Maths.radians(degrees) );
		t.rotation = rot;
	}

	/*
	static public function convertToLocalScale(t:Transform, scale:Vector) : Vector {
		var localScale = scale.clone().divide(t.scale);
		var parent = t.parent;
		while (parent != null) {
			localScale.divide(parent.scale);
			parent = parent.parent;
		}
		return localScale;
	}
	*/

	static public function worldRotationToLocalRotationZ(t:Transform, rotation_z:Float) : Float {
		var euler = new Vector().setEulerFromQuaternion(t.rotation);
		rotation_z -= Maths.degrees(euler.z);
		if (t.parent != null) {
			rotation_z = t.parent.worldRotationToLocalRotationZ(rotation_z);
		}
		return rotation_z;
	}

	static public function worldVectorToLocalSpace(t:Transform, v:Vector) : Vector {
		return v.toLocalSpace(t);
	}

	static public function localVectorToWorldSpace(t:Transform, v:Vector) : Vector {
		return v.toWorldSpace(t);
	}
}

class PolylineExtender {
	static public function closestIndex(points:Array<Vector>, otherPoint:Vector) : Int {
		var closestIndex = 0;
		for (i in 0 ... points.length) {
			if (otherPoint.distance(points[i]) < otherPoint.distance(points[closestIndex])) {
				closestIndex = i;
			}
		}
		return closestIndex;
	}

	static public function closestVertex(points:Array<Vector>, otherPoint:Vector) : Vector {
		return points[points.closestIndex(otherPoint)];
	}

	static public function closestPoint(points:Array<Vector>, otherPoint:Vector) : Vector {

		var closestPoint = points[0].clone();

		for (i in 0 ... points.length - 1) {

			var a = points[i];
			var b = points[i+1];

			var p = otherPoint.closestPointOnLine( a, b );

			if ( otherPoint.distance(p) < otherPoint.distance(closestPoint) ) {
				closestPoint = p;
			}
		}

		return closestPoint;

	}

	static public function clone(points:Array<Vector>) : Array<Vector> {
		var polylineClone = [];
		for (p in points) {
			polylineClone.push(p.clone());
		}
		return polylineClone;
	}

	static public function makeCirclePolyline(points:Array<Vector>, center:Vector, radius:Float, ?steps:Int) {
		points = [];
		if (steps == null) steps = 60;
		for (i in 0 ... steps) {
			var degrees : Float = (i / steps) * 360.0;
			var pDir = (new Vector()).setFromAngle(Maths.radians(degrees));
			var p = Vector.Add(center, pDir.multiplyScalar(radius));
			points.push(p);
		}
		return points;
	}

	static public function toLocalSpace(points:Array<Vector>, t:Transform) : Array<Vector> {
		return points.clone().map( function(p) { return p.toLocalSpace(t); } );
	}

	static public function toWorldSpace(points:Array<Vector>, t:Transform) : Array<Vector> {
		return points.clone().map( function(p) { return p.toWorldSpace(t); } );
	}

	//what is this doing in polyline extender?
	static public function testLineIntersection(a:Vector, b:Vector, c:Vector, d:Vector) {
		var p = a;
		var q = c;

		var r = Vector.Subtract(b, a);
		var s = Vector.Subtract(d, c);

		var qMinusP = Vector.Subtract(q, p);

		var rCrossS = r.cross2D(s);

		if (rCrossS != 0) {
			var t = qMinusP.cross2D(s) / rCrossS;
			var u = qMinusP.cross2D(r) / rCrossS;

			if (t <= 1 && t >= 0 && u <= 1 && u >= 0) {
				var rTimesT = Vector.Multiply(r, t);
				var result = Vector.Add(p, rTimesT);
				return {intersects: true, intersectionPoint: result};
			}
		}

		return {intersects: false, intersectionPoint: null};
	}

	static public function polylineIntersections(points:Array<Vector>) {
		var intersectionList = [];

		if (points.length >= 2) {
			for (i in 0 ... (points.length - 1)) {
				var a = points[i];
				var b = points[i+1];

				for (j in (i+2) ... (points.length - 1)) { //(i+2) is a hack to avoid colliding with next connected line segment
					var c = points[j];
					var d = points[j+1];

					var test = testLineIntersection(a,b,c,d);
					if (test.intersects) {
						intersectionList.push({point: test.intersectionPoint, lineIndex1: i, lineIndex2: j});
					}
				}
			}
		}

		return {intersects: intersectionList.length > 0, intersectionList: intersectionList};
	}

	static public function polylineSplit(points:Array<Vector>, intersection:{point:Vector, lineIndex1:Int, lineIndex2:Int}) {
		//construct closed loop created by intersection
		var closedLoop = points.slice(intersection.lineIndex1+1, intersection.lineIndex2+1);
		closedLoop.push(intersection.point);

		//construct remaining open line
		var openLine = points.slice(0, intersection.lineIndex1+1);
		openLine.push(intersection.point);
		openLine.concat(points.slice(intersection.lineIndex2+1));

		//return the two new lines
		return {openLine: openLine, closedLine: closedLoop};
	}

	static public function polylineCenter(points:Array<Vector>) {
		var center = new Vector(0,0);
		for (p in points) {
			center.add(p);
		}
		center.divideScalar(points.length);
		return center;
	}

	static public function collisionShape(points:Array<Vector>, pos:Vector) {
		return new PolygonCollisionShape(pos.x, pos.y, points.clone());
	}
}
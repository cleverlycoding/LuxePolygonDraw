package ledoux;

import luxe.Vector;
import luxe.Transform;
import luxe.Matrix;
import luxe.Quaternion;
import luxe.utils.Maths;

using Lambda;

class VectorExtender {
	static public function distance(pos1:Vector, pos2:Vector) : Float {
		return Vector.Subtract(pos1, pos2).length;
	}

	static public function cross2D(v1:Vector, v2:Vector) : Float {
		return (v1.x * v2.y) - (v1.y * v2.x);
	}

	//DO THESE FUNCTIONS NEED RECURSION?? (check later)
	static public function toLocalSpace(v:Vector, t:Transform) : Vector {
		var localV : Vector;
		if (t.parent != null) {
			localV = toLocalSpace(v, t.parent);
		}
		localV = v.clone().transform(t.world.matrix.inverse());
		return localV;
	}

	static public function toWorldSpace(v:Vector, t:Transform) : Vector {
		var worldV : Vector;	
		worldV = v.clone().transform(t.world.matrix);
		if (t.parent != null) {
			worldV = toWorldSpace(v, t.parent);
		}
		return worldV;
	}

	static public function absolute(v:Vector) : Vector {
		return new Vector(Math.abs(v.x), Math.abs(v.y));
	}

	static public function setFromAngle(v:Vector, radians:Float) : Vector {
		v = new Vector(Math.cos(radians), Math.sin(radians));
		return v;
	}
}

class TransformExtender {
	static public function up(t:Transform) {
		var upV = new Vector(0.0, 1.0);
		upV.applyQuaternion(t.rotation);
		return upV;
	}

	static public function right(t:Transform) {
		var rightV = new Vector(1.0, 0.0);
		rightV.applyQuaternion(t.rotation);
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
}

class ArrayExtender {
	static public function clone(arr:Array<Dynamic>) : Array<Dynamic> {
		var arrClone = [];
		for (a in arr) {
			arrClone.push(a.clone());
		}
		return arrClone;
	}
}

class PolylineExtender {
	static public function makeCirclePolyline(points:Array<Vector>, center:Vector, radius:Float, ?steps:Int) {
		points = [];
		if (steps == null) steps = 60;
		trace(steps);
		for (i in 0 ... steps) {
			trace(i);
			var degrees : Float = (i / steps) * 360.0;
			trace(degrees);
			var pDir = VectorExtender.setFromAngle(new Vector(), Maths.radians(degrees));
			var p = Vector.Add(center, pDir.multiplyScalar(radius));
			trace(p);
			points.push(p);
		}
		return points;
	}

	static public function toLocalSpace(points:Array<Vector>, t:Transform) : Array<Vector> {
		return ArrayExtender.clone(points).map( function(p) { return VectorExtender.toLocalSpace(p, t); } );
	}

	static public function toWorldSpace(points:Array<Vector>, t:Transform) : Array<Vector> {
		return ArrayExtender.clone(points).map( function(p) { return VectorExtender.toWorldSpace(p, t); } );
	}

	static public function testLineIntersection(a:Vector, b:Vector, c:Vector, d:Vector) {
		var p = a;
		var q = c;

		var r = Vector.Subtract(b, a);
		var s = Vector.Subtract(d, c);

		var qMinusP = Vector.Subtract(q, p);

		var rCrossS = VectorExtender.cross2D(r, s);

		if (rCrossS != 0) {
			var t = VectorExtender.cross2D(qMinusP, s) / rCrossS;
			var u = VectorExtender.cross2D(qMinusP, r) / rCrossS;

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
}
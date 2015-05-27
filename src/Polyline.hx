import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher; //necessary to access PrimitiveType

using utilities.VectorExtender;
using utilities.PolylineExtender;

class Polyline extends Visual {
	var points:Array<Vector>;

	public override function new(_options:luxe.options.VisualOptions, points:Array<Vector>) {
		super(_options);

		this.points = points;

		recenter();

		geometry = new Geometry({
			primitive_type: PrimitiveType.line_strip,
			batcher: Luxe.renderer.batcher
		});

		generateMesh();
	}

	function generateMesh() {
		geometry.vertices = []; //clear mesh (probably a bad idea for performance but meh)
		for (p in points) {
			geometry.add(new Vertex(p,color));
		}
	}

	public function setPoints(points:Array<Vector>) {
		this.points = points;
		generateMesh(); //regenerate mesh whenever you change the number of points
	}

	public function getPoints(): Array<Vector> {
		return points.toWorldSpace(transform);
	}

	public function addPoint(p:Vector) {
		//put points back in world space to add world-space point
		points = points.toWorldSpace(transform);
		points.push(p);
		//re-center polyline
		recenter();

		//re-generate mesh
		generateMesh(); //regenerate mesh whenever you add a point (probably inefficient)
	}

	public function getStartPoint(): Vector {
		return getPoints()[0];
	}

	public function getEndPoint(): Vector {
		return getPoints()[points.length-1];
	}

	function recenter() {
		var c = points.polylineCenter();
		transform.pos.add(c);
		points = points.toLocalSpace(transform);
	}
}
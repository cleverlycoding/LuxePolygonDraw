import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher; //necessary to access PrimitiveType

class Polyline extends Visual {
	var points:Array<Vector>;

	public override function new(_options:luxe.options.VisualOptions, points:Array<Vector>) {
		super(_options);

		this.points = points;

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
		return points;
	}

	public function addPoint(p:Vector) {
		points.push(p);
		generateMesh(); //regenerate mesh whenever you add a point (probably inefficient)
	}

	public function getStartPoint(): Vector {
		return points[0];
	}

	public function getEndPoint(): Vector {
		return points[points.length-1];
	}
}
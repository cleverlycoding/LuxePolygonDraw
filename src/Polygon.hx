import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher; //necessary to access PrimitiveType

class Polygon extends Visual {
	var points:Array<Vector>;

	public override function new(_options:luxe.options.VisualOptions, points:Array<Vector>, ?jsonObj) {
		super(_options);

		this.points = points;

		if (jsonObj != null) {
			this.color = new Color(jsonObj.color.r, jsonObj.color.g, jsonObj.color.b, jsonObj.color.a);

			this.points = [];
			for (jp in cast(jsonObj.points, Array<Dynamic>)) {
				this.points.push(new Vector(jp.x, jp.y));
			}
		}

		geometry = new Geometry({
			primitive_type: PrimitiveType.triangles,
			batcher: Luxe.renderer.batcher
		});

		generateMesh();

	}

	function generateMesh() {
		var p2t = new org.poly2tri.VisiblePolygon();
		p2t.addPolyline(convertVectorsToPoly2TriPoints(points));
		p2t.performTriangulationOnce();

		var results = p2t.getVerticesAndTriangles();
		
		var i = 0;
		while (i < results.triangles.length) {
			for (j in i ... (i+3)) {
				var vIndex = results.triangles[j] * 3;

				var x = results.vertices[vIndex + 0];
				var y = results.vertices[vIndex + 1];
				var z = results.vertices[vIndex + 2];

				var vertex = new Vertex(new Vector(x, y, z), color);

				geometry.add(vertex);
			}

			i += 3;
		}
	}

	function convertVectorsToPoly2TriPoints(vectors:Array<Vector>) : Array<org.poly2tri.Point> {
		var pointArray = [];
		for (v in vectors) {
			pointArray.push(new org.poly2tri.Point(v.x, v.y));
		}
		return pointArray;
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

	public function getJsonRepresentation() {
		var jsonPoints = [];
		for (p in points) {
			jsonPoints.push({x: p.x, y: p.y});
		}

		var jsonColor = {r: color.r, g: color.g, b: color.b, a: color.a};

		return {color: jsonColor, points: jsonPoints};
	}
}
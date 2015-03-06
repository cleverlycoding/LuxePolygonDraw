package components;
import components.EditorComponent;
import luxe.Component;

import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.Vertex;

import Polygon;

using ledoux.UtilityBelt.VectorExtender;
using ledoux.UtilityBelt.PolylineExtender;

class JellyEdges extends EditorComponent {

	var polygon : Polygon;

	var jellyVertices : Array<JellyVertex>;

	var canJiggle = true;

	override function init() {
		polygon = cast entity;

		//make jelly vertices
		jellyVertices = [];
		for (i in 0 ... polygon.points.length) {
			jellyVertices.push( new JellyVertex(polygon, i) );
		}

		//connect neighbors along the edge loop
		for (i in 0 ... jellyVertices.length) {
			var nextIndex = (i + 1) % jellyVertices.length;
			connectNeighbors(jellyVertices[i], jellyVertices[nextIndex]);
		}

		//test
		//jellyVertices[Maths.random_int(0,jellyVertices.length)].addForce(new Vector(0, 100)); //jiggle random vertex

		entity.events.listen('collision_enter', on_collision_enter);
	}

	override function update(dt : Float) {
		for (j in jellyVertices) {
			j.update(dt);
		}
	}

	override function onremoved() {
	}

	function connectNeighbors(n1 : JellyVertex, n2 : JellyVertex) {
		n1.addNeighbor(n2);
		n2.addNeighbor(n1);
	}

	function on_collision_enter(collision) {
		if (canJiggle) {
			jellyVertices[polygon.getPoints().closestIndex(collision.other.entity.pos)].addForce(collision.data.unitVector.multiplyScalar(100));
			canJiggle = false;
			Luxe.timer.schedule( 2, function() {canJiggle = true;} );
		}
	}

}

class JellyVertex {
	var parentPoly : Polygon;

	var pointIndex : Int;
	var vertexIndices : Array<Int> = [];

	public var pos : Vector;
	var startPos : Vector;
	var anchors : Array<Vector> = [];
	var neighbors : Array<JellyVertex> = [];

	//spring forces
	var springConstant : Float = 10;
	var velocity : Vector = new Vector(0,0);
	var totalForce : Vector = new Vector(0,0);

	var muffleFactor : Float = 0.5; // decreases how much force gets transmitted to neighbors
	var playRadius : Float; //how far the vertex can stray from its start point
	var playFactor : Float = 0.6; //can be used to increase or decrease play
	var friction : Float = 0.5; //moving vertices always slow down

	var isDebug = false;

	public function new(polygon : Polygon, index : Int) {

		//basic initialization
		parentPoly = polygon;
		pointIndex = index;
		startPos = polygon.points[pointIndex].clone();
		pos = startPos.clone();

		initAnchorsAndVertices();

		//init null neighbors array
		for (i in 0 ... anchors.length) { //this is hacky as fuck, probably
			neighbors.push(null);
		}

	}

	public function update(dt : Float) {
		//add up anchor forces
		for (i in 0 ... anchors.length) {

			var a = anchors[i];

			var f = Vector.Subtract(pos, a).normalized;
			f.multiplyScalar( springForce(a) * dt ); //important: apply spring forces evenly over time 
			addForce(f);

			if (neighbors[i] != null) {
				neighbors[i].addForce( f.multiplyScalar(-1 * muffleFactor) ); //push neighbors
			}

		}

		velocity.add(totalForce); //apply forces

		pos.add(Vector.Multiply(velocity, dt)); //move

		velocity.subtract( Vector.Multiply(velocity, friction * dt) ); //apply friction

		keepInsideAnchors();

		totalForce = new Vector(0,0); //reset forces

		updateParentPolygon(); //updates mesh, etc.

		//DEBUG
		if (isDebug) {
			Luxe.draw.ring({
				r : playRadius,
				x : parentPoly.pos.x + startPos.x,
				y : parentPoly.pos.y + startPos.y,
				depth: 2000,
				immediate: true
			});

			Luxe.draw.circle({
				r : 5,
				x : parentPoly.pos.x + pos.x,
				y : parentPoly.pos.y + pos.y,
				depth: 2000,
				immediate: true
			});
		}
	}

	function keepInsideAnchors() {
		if (pos.distance(startPos) > playRadius) {
			var fromStartV = Vector.Subtract(pos, startPos).normalized;
			pos = Vector.Add( startPos, Vector.Multiply(fromStartV, playRadius) );
			velocity.subtract( fromStartV.multiplyScalar( velocity.dot(fromStartV) * 1.5 ) );
		}
	}

	public function addNeighbor(n : JellyVertex) {
		for (i in 0 ... anchors.length) {
			if (anchors[i].equals(n.pos)) {
				neighbors[i] = n;
			}
		}
	}

	public function addForce(force : Vector) {
		totalForce.add(force);
	}

	function updateParentPolygon() {
		parentPoly.points[pointIndex] = pos.clone();

		for (index in vertexIndices) {
			parentPoly.geometry.vertices[index].pos = pos.clone();
		}
	}

	/*
	 * Spring Force Equation
	 * ---
	 * Fs = Ks * s
	 * Ks = L0 - L
	 * ---
	 * L0 = relaxedLength()
	 * L = stretchedLength()
	 * s = springConstant
	 */
	function springForce(anchor : Vector) : Float {
		var Ks = relaxedLength(anchor) - stretchedLength(anchor);
		var Fs = Ks * springConstant;
		return Fs;
	}

	function relaxedLength(anchor : Vector) : Float {
		return startPos.distance(anchor);
	}

	function stretchedLength(anchor : Vector) : Float {
		return pos.distance(anchor);
	}

	function initAnchorsAndVertices() {
		//find anchors and vertex indices
		var i = 0;
		while (i < parentPoly.geometry.vertices.length) { //search all triangles in the mesh
			var v0 = parentPoly.geometry.vertices[i];
			var v1 = parentPoly.geometry.vertices[i+1];
			var v2 = parentPoly.geometry.vertices[i+2];

			var tri = [v0, v1, v2];

			var j = 0;
			for (v in tri) {

				//is this vertex located in this triangle in the mesh?
				if (v.pos.equals(startPos)) { 

					//add related vertex indices in mesh
					vertexIndices.push(i + j);

					//add anchor positions for the spring
					tri.remove(v);
					for (vOther in tri) {

						var hasEqualAnchor = false;
						for (a in anchors) {
							if (a.equals(vOther.pos)) hasEqualAnchor = true;
						}

						if (!hasEqualAnchor) anchors.push(vOther.pos.clone());

					}

					break; //exit for loop

				}

				j++;
			}

			i += 3;
		}

		//calculate play
		playRadius = startPos.distance(anchors[0]);
		for (a in anchors) {
			if (startPos.distance(a) < playRadius) playRadius = startPos.distance(a);
		}
		playRadius *= playFactor;
	}
}
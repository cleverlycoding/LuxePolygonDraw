package components;
import components.EditorComponent;

import luxe.Vector;

import animation.Bone;

using ledoux.UtilityBelt.TransformExtender;
using ledoux.UtilityBelt.VectorExtender;

/*
 * A simplified animation class that
 * only supports one-to-one bindings
 * between bones and polygons,
 * with no weighting effect.
 * 
 * Named for resemblance between
 * the animation effect and
 * puppets in shadow plays.
 */
class PuppetAnimation extends EditorComponent {

	var polygon : Polygon;
	public var bone (default, set) : Bone;
	var vertexDisplacements : Array<Vector>;

	override function init() {
		polygon = cast entity;
	}

	/*
	 * TODO: use event binding to only call these changes
	 * when a bone rotates or scales itself
	 */
	override function update(dt : Float) {
		for ( i in 0 ... polygon.geometry.vertices.length ) {
			var worldDisplacement = bone.transform.localVectorToWorldSpace(vertexDisplacements[i]);
			var updatedVertPos = polygon.transform.worldVectorToLocalSpace(worldDisplacement);

			polygon.geometry.vertices[i].pos = updatedVertPos;
		}
	}

	function set_bone(newBone : Bone) : Bone {
		bone = newBone;

		//find vertex positions relative to bone
		vertexDisplacements = [];
		for ( i in 0 ... polygon.geometry.vertices.length ) {
			var vertWorldPos = polygon.transform.localVectorToWorldSpace(polygon.geometry.vertices[i].pos);
			var disp = bone.transform.worldVectorToLocalSpace(vertWorldPos);
			vertexDisplacements.push(disp);
		}

		return bone;
	}
}
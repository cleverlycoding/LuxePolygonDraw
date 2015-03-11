package components;
import components.EditorComponent;

import luxe.Vector;
import luxe.Color;

import animation.Bone;

using ledoux.UtilityBelt.TransformExtender;
using ledoux.UtilityBelt.VectorExtender;

typedef VertexBoneMapping = {
	public var vertexIndex : Int;
	public var boneIndex : Int;
	public var localPos : Vector;
}

class Animation extends EditorComponent {
	
	var polygon : Polygon;

	public var skeletonRoot (default, set) : Bone;
	var skeleton : Array<Bone>;

	var skeletonMap : Array<VertexBoneMapping>;

	override function init() {
		polygon = cast entity;
	}

	override function update(dt : Float) {
		//I bet this is WILDLY inefficient
		for (mapping in skeletonMap) {

			var bone = skeleton[mapping.boneIndex];
			var worldPos = bone.transform.localVectorToWorldSpace(mapping.localPos);
			var vertPos = polygon.transform.worldVectorToLocalSpace(worldPos);

			polygon.geometry.vertices[mapping.vertexIndex].pos = vertPos;

			/*
			var bone = skeleton[mapping.boneIndex];
			var localDisplacement = bone.transform.worldVectorToLocalSpace(mapping.worldDisplacement);


			var localPos = bone.pos.clone().add(localDisplacement);
			var worldPos = bone.transform.localVectorToWorldSpace(localPos);
			var polyLocalPos = polygon.transform.worldVectorToLocalSpace(worldPos);
			polygon.geometry.vertices[mapping.vertexIndex].pos = polyLocalPos;


			//debug!!
			Luxe.draw.circle({
				r : 5,
				x : localPos.x, y : localPos.y,
				color : new Color(255,0,0),
				immediate : true
			});

			Luxe.draw.circle({
				r : 5,
				x : worldPos.x, y : worldPos.y,
				color : new Color(0,255,0),
				immediate : true
			});

			Luxe.draw.circle({
				r : 5,
				x : polyLocalPos.x, y : polyLocalPos.y,
				color : new Color(0,0,255),
				immediate : true
			});
			*/
		}
	}

	function set_skeletonRoot(root : Bone) : Bone {
		skeletonRoot = root;

		skeleton = root.skeleton();
		makeMeshToSkeletonMapping();

		return skeletonRoot;
	}

	function makeMeshToSkeletonMapping() {

		skeletonMap = [];

		var i = 0;
		for (vert in polygon.geometry.vertices) {

			//find closest bone
			var vertWorldPos = polygon.transform.localVectorToWorldSpace(vert.pos);

			var closestBone = 0;
			var closestDist = skeleton[closestBone].closestWorldPoint(vertWorldPos).distance(vertWorldPos);

			var j = 0;
			for (bone in skeleton) {

				var curDist = bone.closestWorldPoint(vertWorldPos).distance(vertWorldPos);

				if (curDist < closestDist) {
					closestBone = j;
					closestDist = curDist;
				}

				j++;
			}

			//calc displacement in the world coords
			/*
			var boneWorldPos = skeleton[closestBone].worldPos();
			var disp = Vector.Subtract(boneWorldPos, vertWorldPos);
			*/

			var posRelToBone = skeleton[closestBone].transform.worldVectorToLocalSpace(vertWorldPos);

			//create mapping
			var mapping = {vertexIndex : i, boneIndex : closestBone, localPos : posRelToBone};
			skeletonMap.push(mapping);

			i++;
		}

		trace(skeletonMap);
	}
}
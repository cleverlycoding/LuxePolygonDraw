package animation;

import luxe.Vector;
import luxe.Color;

using utilities.TransformExtender;
using utilities.VectorExtender;

using Lambda;

typedef VertexBoneMapping = {
	public var vertex : Int;
	public var bones : Array<Int>;
	public var weights : Array<Float>;
	public var displacements : Array<Vector>;
}

class Rigging {
	var polygon : Polygon;
	public var bones : Array<Bone> = [];
	public var mapping : Array<VertexBoneMapping> = [];

	public function new(polygon : Polygon) {
		this.polygon = polygon; //this is kinda awkward
	}

	public static function createFromJson(polygon : Polygon, json : Dynamic) : Rigging {
		var newRigging = new Rigging(polygon);

		//find & add bones
		trace("_____");
		trace(json.boneNames);
		var bl = Main.instance.getAllBonesInScene();
		trace(bl);
		for (b in bl) { //there has GOT to be a better way of doing this
			trace(b.name);
			if (json.boneNames.indexOf(b.name) != -1) {
				trace(b);
				newRigging.bones.push(b);
			}
		}

		//apply mapping
		newRigging.mapping = json.mapping;

		return newRigging;
	}

	public function morphMesh() {
		for (m in mapping) {
			
			var weightedVertPos = new Vector(0,0);

			
			for (i in 0 ... m.bones.length) {

				var bone = bones[m.bones[i]];
				var weight = m.weights[i];

				var worldPos = bone.transform.localVectorToWorldSpace(m.displacements[i]);
				var vertPos = polygon.transform.worldVectorToLocalSpace(worldPos);

				weightedVertPos.add(vertPos.multiplyScalar(weight));
			}

			polygon.geometry.vertices[m.vertex].pos = weightedVertPos;

		}
	}

	public function rigged() : Bool {
		return mapping.length > 0;
	}

	public function addBones(addList : Array<Bone>) {
		for (b in addList) {
			if (bones.indexOf(b) == -1) bones.push(b);
		}
		mapMeshToBones();
	}

	public function removeBones(removeList : Array<Bone>) {
		for (b in removeList) {
			if (bones.indexOf(b) != -1) bones.remove(b);
		}
		mapMeshToBones();
	}

	public function drawRigging() {
		for (m in mapping) {
			for (i in 0 ... m.bones.length) {

				var bone = bones[m.bones[i]];
				var vertPos = polygon.transform.localVectorToWorldSpace( polygon.geometry.vertices[m.vertex].pos );
			
				Luxe.draw.line({
					p0 : bone.closestWorldPoint(vertPos),
					p1 : vertPos,
					immediate : true,
					depth : 2000,
					color : new Color(1,1,1)
				});

			}
		}
	}

	public function jsonRepresentation() {
		return {
			boneNames: bones.map( function(b) { return b.name; } ),
			mapping: mapping
		};
	}

	function mapMeshToBones() {

		mapping = [];

		if (bones.length > 0) {

			var i = 0;
			for (vert in polygon.geometry.vertices) {

				//find closest bone
				var vertWorldPos = polygon.transform.localVectorToWorldSpace(vert.pos);

				var closestBone = 0;
				var closestDist = bones[closestBone].closestWorldPoint(vertWorldPos).distance(vertWorldPos);

				
				var closeBones = [];
				var closeDistList = [];

				var j = 0;
				for (bone in bones) {

					var curDist = bone.closestWorldPoint(vertWorldPos).distance(vertWorldPos);

					if (curDist < closestDist) {
						closestBone = j;
						closestDist = curDist;
					}

					
					//if (curDist < maxInfluenceDistance) {
						closeBones.push(j);
						
						closeDistList.push(curDist);
					//}

					j++;
				}

				closeBones = [closestBone];

				var weights = [1.0];

				//calc displacements
				var displacements = closeBones.map(function(b) { return bones[b].transform.worldVectorToLocalSpace(vertWorldPos); });

				//create mapping
				var newMapping = {
					vertex : i,
					bones : closeBones,
					weights : weights,
					displacements : displacements
				};
				mapping.push(newMapping);
				

				i++;
			}	
			
		}

	}
}
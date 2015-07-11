package components;
import components.EditorComponent;

import luxe.Vector;
import luxe.Color;

import animation.Bone;

using utilities.TransformExtender;
using utilities.VectorExtender;

import luxe.options.ComponentOptions;

typedef VertexBoneMapping = {
	public var vertex : Int;
	public var bones : Array<Int>;
	public var weights : Array<Float>;
	public var displacements : Array<Vector>;
}

//TO DO - REPLACE THIS WHOLE DAMN CLASS WITH, LIKE, SOME INNER CLASS OF POLYGON????

class Rigging extends EditorComponent {
	
	var polygon : Polygon;

	//public var boneListRoot (default, set) : Bone;
	@editor
	public var boneNames : Array<String> = [];
	public var boneList : Array<Bone> = [];

	var boneListMap : Array<VertexBoneMapping> = [];

	//DEBUG
	var isDebug = false;

	override public function new(_options:ComponentOptions) {
		super(_options);
		
			
		trace(boneNames); //= null???
			
		//this breaks shit to hell
		//if (boneNames.length > 0) {
			//for (n in boneNames) {
			//	trace(n);
				//trace(Luxe.scene.entities.get(n));
				//boneList.push( cast( Luxe.scene.entities.get(n), Bone ) );
			//}
		//}

		//if (boneList.length > 0) mapMeshToBones(); 
	}

	override function init() {
		polygon = cast entity;

		/*
		for (n in boneNames) {
			boneList.push( cast( Luxe.scene.entities.get(n), Bone ) );
		}
		*/

		if (boneList.length > 0) mapMeshToBones();
	}

	override function update(dt : Float) {
		for (mapping in boneListMap) {
			
			var weightedVertPos = new Vector(0,0);

			
			for (i in 0 ... mapping.bones.length) {

				var bone = boneList[mapping.bones[i]];
				var weight = mapping.weights[i];

				var worldPos = bone.transform.localVectorToWorldSpace(mapping.displacements[i]);
				var vertPos = polygon.transform.worldVectorToLocalSpace(worldPos);

				weightedVertPos.add(vertPos.multiplyScalar(weight));
			}

			polygon.geometry.vertices[mapping.vertex].pos = weightedVertPos;

			//debug
			if (isDebug) {
				for (i in 0 ... mapping.bones.length) {

					var bone = boneList[mapping.bones[i]];
				
					Luxe.draw.line({
						p0 : bone.closestWorldPoint(polygon.transform.localVectorToWorldSpace(weightedVertPos)),
						p1 : polygon.transform.localVectorToWorldSpace(weightedVertPos),
						immediate : true,
						depth : 2000,
						color : new ColorHSV(mapping.weights[i] * 360, 1, 1) 
					});

				}
			}

		}
	}

	/*
	function set_boneListRoot(root : Bone) : Bone {
		boneListRoot = root;

		boneList = root.boneList();
		mapMeshToBones();

		return boneListRoot;
	}
	*/

	/*
	public function setBones(bones : Array<Bone>) {
		boneList = bones;
		mapMeshToBones();
	}

	*/

	public function drawRigging() {
		for (mapping in boneListMap) {
			for (i in 0 ... mapping.bones.length) {

				var bone = boneList[mapping.bones[i]];
				var vertPos = polygon.transform.localVectorToWorldSpace( polygon.geometry.vertices[mapping.vertex].pos );
			
				Luxe.draw.line({
					p0 : bone.closestWorldPoint(vertPos),
					p1 : vertPos,
					immediate : true,
					depth : 2000,
					//color : new ColorHSV(mapping.weights[i] * 360, 1, 1) 
					color : new Color(1,1,1)
				});

			}
		}
	}
	
	public function addBones(bones : Array<Bone>) {
		for (b in bones) {
			if (boneList.indexOf(b) == -1) boneList.push(b);
		}
		mapMeshToBones();
		if (hasComponentRegistryEntry()) updateBoneNamesInComponentRegistry();
	}

	//THIS BREAKS
	public function removeBones(bones : Array<Bone>) {
		for (b in bones) {
			if (boneList.indexOf(b) != -1) boneList.remove(b);
		}
		mapMeshToBones();
		if (hasComponentRegistryEntry()) updateBoneNamesInComponentRegistry();
	}

	//there must be a more elegant method to do this
	function hasComponentRegistryEntry() {
		return Main.instance.componentManager.getEntry(this.entity) != null;
	}

	function updateBoneNamesInComponentRegistry() {
		
		boneNames = [];
		for (b in boneList) {
			boneNames.push(b.name);
		}

		var entry = Main.instance.componentManager.getEntry(this.entity);
		for (c in entry.components) {
			if (c.name == "Rigging") {
				c.boneNames = boneNames;
			}
		}

	}

	function mapMeshToBones() {

		boneListMap = [];

		if (boneList.length > 0) {

			var i = 0;
			for (vert in polygon.geometry.vertices) {

				//find closest bone
				var vertWorldPos = polygon.transform.localVectorToWorldSpace(vert.pos);

				var closestBone = 0;
				var closestDist = boneList[closestBone].closestWorldPoint(vertWorldPos).distance(vertWorldPos);

				
				var closeBones = [];
				var closeDistList = [];

				var j = 0;
				for (bone in boneList) {

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
				var displacements = closeBones.map(function(b) { return boneList[b].transform.worldVectorToLocalSpace(vertWorldPos); });

				//create mapping
				var mapping = {
					vertex : i,
					bones : closeBones,
					weights : weights,
					displacements : displacements
				};
				boneListMap.push(mapping);
				

				i++;
			}	
			
		}

	}
}
package components;

import components.EditorComponent;
import luxe.Component;
import luxe.Vector;
import luxe.Color;
import luxe.Input.MouseEvent;
import luxe.Rectangle;
import luxe.Visual;
import phoenix.geometry.RectangleGeometry;
import phoenix.geometry.CircleGeometry;
import luxe.utils.Maths;
import phoenix.Transform;

import luxe.collision.Collision;
import luxe.collision.shapes.Polygon in CollisionPoly;

using utilities.VectorExtender;
using utilities.TransformExtender;

class LayerControl extends EditorComponent {

	var polygon : Polygon;
	var bounds : Rectangle;

	var isSelectingLayer : Bool;
	var isMovingLayer : Bool;
	var isGrouping : Bool;
	
	var thumbnailPoly : Polygon; 
	var groupHandle : Visual;
	var enterGroupHandle : Visual;

	var closestLayerToGroupHandle : Int;

	var prevSelectedLayer : Int;
	var prevNumlayers : Int;

	override function init() {
		polygon = cast entity;
		bounds = polygon.getRectBounds();

		//create extra geometry
		groupHandle = new Visual({
			pos: new Vector(bounds.x - 15, bounds.y),
			color: new Color(0,1,0),
			depth: 2000,
			immediate: false,
			geometry: Luxe.draw.circle({r:10})
		});
		//why is this hack necessary?
		Luxe.renderer.batcher.remove(groupHandle.geometry);
		Main.instance.uiSceneBatcher.add(groupHandle.geometry);

		enterGroupHandle = new Visual({
			pos: new Vector(bounds.x + bounds.w + 110, bounds.y),
			color: new Color(1,0,1),
			depth: 2000,
			immediate: false,
			geometry: Luxe.draw.circle({r:15})
		});
		//why is this hack necessary?
		Luxe.renderer.batcher.remove(enterGroupHandle.geometry);
		Main.instance.uiSceneBatcher.add(enterGroupHandle.geometry);
	}

	override function update(dt : Float) {
		var numLayers = Main.instance.layers.length;

		var i = 0;

		for (h in layerLineHeights()) {

			var isSelectedLayer = (i == Main.instance.curLayer);
			var isSelectedGroup = ( isGrouping && 
									((closestLayerToGroupHandle > Main.instance.curLayer 
										&& i <= closestLayerToGroupHandle && i > Main.instance.curLayer) || 
									(closestLayerToGroupHandle < Main.instance.curLayer 
										&& i >= closestLayerToGroupHandle && i < Main.instance.curLayer)) );
			var c = (isSelectedLayer || isSelectedGroup) ? new Color(255,255,0) : new Color(255,255,255);

			Luxe.draw.line({
				p0: new Vector(bounds.x, h),
				p1: new Vector(bounds.x + bounds.w, h),
				immediate: true,
				color: c,
				depth: 1000,
				//batcher: Luxe.renderer.batcher
				batcher: Main.instance.uiSceneBatcher
			});

			i++;
		}

		if (Main.instance.layers != Main.instance.rootLayers) {
			Luxe.draw.circle({
				x: bounds.x + bounds.w/2 - 15,
				y: bounds.y - 20,
				r: 15,
				immediate: true,
				color: new Color(1,1,0),
				depth: 1000,
				batcher: Main.instance.uiSceneBatcher
			});
		}

		if (Main.instance.layers.length > 0 && (prevSelectedLayer != Main.instance.curLayer || prevNumlayers != numLayers)) {
			updateSelectedLayerHandles();
		} 

		prevSelectedLayer = Main.instance.curLayer;
		prevNumlayers = numLayers;
	}

	override function onmousedown(e : MouseEvent) {

		if (e.pos.distance(groupHandle.pos) < 15) {
			if (Main.instance.curPoly().children.length > 0) {
				unGroup(Main.instance.curPoly());
			}
			else {
				isGrouping = true;
			}
		}
		else if (e.pos.distance(enterGroupHandle.pos) < 15 && Main.instance.curPoly().children.length > 0) {
			editGroup(Main.instance.curPoly());
		}
		else if (e.pos.distance(new Vector(bounds.x + bounds.w/2 - 15, bounds.y - 20)) < 15 && 
			Main.instance.layers != Main.instance.rootLayers) {
			exitCurrentGroup();
		}
		if ( Collision.pointInPoly(e.pos, polygon.getRectCollisionBounds()) ) {
			selectLayerWithCursor(e.pos.y);
			isSelectingLayer = true;
		}
		else if ( thumbnailPoly != null && Collision.pointInPoly(e.pos, thumbnailPoly.getRectCollisionBounds()) ) {
			isMovingLayer = true;
		}
	}

	override function onmousemove(e : MouseEvent) {
		if (isGrouping) {
			moveGroupingSelector(e.pos.y);
		}
		if ( isSelectingLayer ) {
			selectLayerWithCursor(e.pos.y);
		}
		else if (isMovingLayer) {
			moveLayerWithCursor(e.pos.y);
		}
	}

	override function onmouseup(e : MouseEvent) {
		if (isMovingLayer && e.pos.y > bounds.y + bounds.h) {
			var curP = Main.instance.curPoly();
			Edit.RemoveLayer(Main.instance.layers, 0);
		}
		else if (isGrouping && closestLayerToGroupHandle != Main.instance.curLayer) {
			mergeGroup();
		}

		isSelectingLayer = false;
		isMovingLayer = false;
		isGrouping = false;
	}

	function exitCurrentGroup() {
		if (Main.instance.layers[0].parent.parent != null) {
			var newParent = cast(Main.instance.layers[0].parent.parent, Polygon);
			Main.instance.layers = newParent.getChildrenAsPolys();
			Main.instance.localSpace = newParent.transform;
		}
		else {
			Main.instance.layers = Main.instance.rootLayers;
			//Main.instance.localSpace = null;
			Main.instance.localSpace = new Transform(); 
			//this is kind of a crappy hack - should I have a global root polygon??
			//or do I need to restructure groups so they don't use empty polygons as containers???
		}

		//hack to prevent crashes until I care about fixing this better
		Main.instance.curLayer = 0;

		updateSelectedLayerHandles();
	}

	function editGroup(parent : Polygon) {
		Main.instance.layers = parent.getChildrenAsPolys();
		Main.instance.localSpace = parent.transform;
		Main.instance.curLayer = 0;

		updateSelectedLayerHandles();
	}

	//BUGGY AS FUCK
	//NOTE: THIS MIGHT NOT WORK FOR DEEP LAYERS
	function unGroup(parent : Polygon) {
		//keep track of layer indices
		var i = Main.instance.curLayer;
		var tmpParentPos = parent.pos.clone();
		var tmpParentScale = parent.scale.clone();
		var tmpParentRotZ = parent.rotation_z;

		//remove parent
		Edit.RemoveLayer(Main.instance.layers, i);

		//remove children from parent and keep a list of the polygons
		var polyList : Array<Polygon> = [];
		for (c in parent.children) {
			var p = cast(c, Polygon);
			polyList.push(p);
		}

		//add polygons to parent's layer and re-adjust their transforms to new coord system
		for (p in polyList) {
			var worldPos = p.pos.toWorldSpace(parent.transform);

			p.parent = parent.parent;
			Edit.AddLayer(Main.instance.layers, p, i); //I expect this to break at lower levels

			/*
			var u = p.transform.up();
			var r = p.transform.right();
			trace("u " + u + " - r " + r);

			var scaleYVec = parent.transform.up().multiplyScalar(parent.scale.y);
			var scaleXVec = parent.transform.right().multiplyScalar(parent.scale.x);
			trace("y scale " + scaleYVec + " - x scale " + scaleXVec);

			var rMult = scaleXVec.dot(r) + scaleYVec.dot(r);
			var uMult = scaleXVec.dot(u) + scaleYVec.dot(u);

			var multVec = new Vector(rMult, uMult);
			trace("mult vec " + multVec);
			trace("~~~~~");
			*/

			//can this all be done w/ one transform operation?
			//p.pos.add(tmpParentPos);
			
			//THIS almost seems like it could work, but it resets back to normal for some reason
			//is there something that changes the local matrix automatically hidden in the transform code?
			//(ask Sven Bergstrom)
			/*
			p.transform.world.matrix = p.transform.world.matrix.multiplyMatrices(parent.transform.world.matrix, p.transform.local.matrix);
			p.transform.local.matrix = p.transform.world.matrix.multiplyMatrices(parent.transform.world.matrix, p.transform.local.matrix);
			*/

			p.pos = worldPos;
			//p.scale.multiply(tmpParentScale);
			//p.scale.multiply(multVec);
			p.rotation_z += tmpParentRotZ;

			i++;
		}

		Main.instance.switchLayerSelection(i-1);

		updateSelectedLayerHandles();
	}

	function mergeGroup() {

		var groupLayer = cast(Math.min(closestLayerToGroupHandle, Main.instance.curLayer), Int);

		var polysInGroup = [];
		var i = 0;
		for (l in Main.instance.layers) {

			var isSelectedGroup = ( i == Main.instance.curLayer || 
									((closestLayerToGroupHandle > Main.instance.curLayer 
										&& i <= closestLayerToGroupHandle && i > Main.instance.curLayer) || 
									(closestLayerToGroupHandle < Main.instance.curLayer 
										&& i >= closestLayerToGroupHandle && i < Main.instance.curLayer)) );
			

			if (isSelectedGroup) {
				polysInGroup.push(l);
			}

			i++;

		}

        var parentPoly = new Polygon({}, []);

		for (childPoly in polysInGroup) {
			Main.instance.layers.remove(childPoly);
			childPoly.parent = parentPoly;
		}

		parentPoly.recenter();

		Main.instance.layers.insert(groupLayer, parentPoly);

		Main.instance.switchLayerSelection(groupLayer);

		updateSelectedLayerHandles();
	}

	function moveGroupingSelector(cursorHeight:Float) {
		var clampedHeight = Maths.clamp(cursorHeight, bounds.y, bounds.y + bounds.h);
		groupHandle.pos.y = clampedHeight;
		closestLayerToGroupHandle = findClosestLayer(groupHandle.pos.y);
	}

	function moveLayerWithCursor(cursorHeight:Float) {
		var clampedHeight = Maths.clamp(cursorHeight, bounds.y, bounds.y + bounds.h);

		thumbnailPoly.pos.y = clampedHeight;

		var closestLayer = findClosestLayer(clampedHeight);
		if (closestLayer != Main.instance.curLayer) {
			
			//this works but it's ugly
			var curP = Main.instance.curPoly();
			if (Main.instance.curLayer < closestLayer) {
				while (Main.instance.curLayer != closestLayer) {
					Edit.MoveLayer(Main.instance.layers, Main.instance.curLayer, 1);
					Main.instance.switchLayerSelection(1);
				}
			}
			else {
				while (Main.instance.curLayer != closestLayer) {
					Edit.MoveLayer(Main.instance.layers, Main.instance.curLayer, -1);
					Main.instance.switchLayerSelection(-1);
				}
			}

			Main.instance.goToLayer( closestLayer );
		}
	}

	function findClosestLayer(targetHeight:Float) : Int {
		var i = 0;
		var closestLayer = 0;
		var heights = layerLineHeights();
		for (h in heights) {
			var closestDist = Math.abs(targetHeight - heights[closestLayer]);
			var testDist = Math.abs(targetHeight - h);

			if (testDist < closestDist) {
				closestLayer = i;
			}

			i++;
		}
		return closestLayer;
	}

	function selectLayerWithCursor(cursorHeight:Float) {
		//FIND CLOSEST LAYER
		var closestLayer = findClosestLayer(cursorHeight);

		//SELECT LAYER
		Main.instance.goToLayer(closestLayer);
	}

	function updateSelectedLayerHandles() {
		var closestLayer = Main.instance.curLayer;
		var heights = layerLineHeights();

		//CREATE THUMBNAIL
		if (thumbnailPoly != null) {

			//THIS NEEDS TO BE REFACTORED BRO
			Main.instance.uiSceneBatcher.remove(thumbnailPoly.geometry);
			for (c in thumbnailPoly.children) {
				Main.instance.uiSceneBatcher.remove( cast(c, Visual).geometry );
			}
		}

		var thumbWidth = 100;
		var thumbHeight = 100;
		thumbnailPoly = new Polygon({batcher: Main.instance.uiSceneBatcher, depth: 2000}, [],
										Main.instance.curPoly().jsonRepresentation());

		thumbnailPoly.pos.y = heights[closestLayer];
		thumbnailPoly.pos.x = bounds.x + bounds.w + thumbWidth/2;

		if (thumbnailPoly.getRectBounds().w > thumbnailPoly.getRectBounds().h) {
			var scaleRatio = thumbnailPoly.getRectBounds().w / thumbWidth;
			thumbnailPoly.scale = thumbnailPoly.scale.divideScalar(scaleRatio);
		}
		else {
			var scaleRatio = thumbnailPoly.getRectBounds().h / thumbHeight;
			thumbnailPoly.scale = thumbnailPoly.scale.divideScalar(scaleRatio);
		}

		if (thumbnailPoly.getRectBounds().w > thumbWidth) {
			var scaleRatio = thumbnailPoly.getRectBounds().w / thumbWidth;
			thumbnailPoly.scale = thumbnailPoly.scale.divideScalar(scaleRatio);
		}

		if (thumbnailPoly.getRectBounds().h > thumbHeight) {
			var scaleRatio = thumbnailPoly.getRectBounds().h / thumbHeight;
			thumbnailPoly.scale = thumbnailPoly.scale.divideScalar(scaleRatio);
		}

		groupHandle.pos.y = heights[closestLayer];
		enterGroupHandle.pos.y = heights[closestLayer];

		if (Main.instance.curPoly().children.length > 0) {
			enterGroupHandle.color = new Color(1,0,1);
			groupHandle.color = new Color(1,0,0);
		}
		else {
			enterGroupHandle.color = new Color(0,0,0);
			groupHandle.color = new Color(0,1,0);
		}
	}

	//from lowest to highest
	function layerLineHeights() : Array<Float> {
		var heights : Array<Float> = [];
		var numLayers = Main.instance.layers.length;
		for (i in 0 ... numLayers) {
			var curH = bounds.y + (bounds.h * ( 1 - ((i+1) / (numLayers+1)) ) );
			heights.push(curH);
		}
		return heights;
	}

}
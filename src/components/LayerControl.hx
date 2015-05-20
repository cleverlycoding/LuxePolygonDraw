package components;

import components.EditorComponent;
import luxe.Component;
import luxe.Vector;
import luxe.Color;
import luxe.Input.MouseEvent;
import luxe.Rectangle;
import luxe.Visual;

import luxe.collision.Collision;
import luxe.collision.shapes.Polygon in CollisionPoly;

class LayerControl extends EditorComponent {

	var polygon : Polygon;
	var bounds : Rectangle;

	var isActive : Bool;
	
	var thumbnailPoly : Polygon; 

	override function init() {
		polygon = cast entity;
		bounds = polygon.getRectBounds();
	}

	override function update(dt : Float) {
		var numLayers = Main.instance.layers.getNumLayers();

		/*
		for (i in 0 ... numLayers) {
			var curH = bounds.y + (bounds.h * ( 1 - ((i+1) / (numLayers+1)) ) );
			var c = (i == Main.instance.curLayer) ? new Color(255,255,0) : new Color(255,255,255);
			Luxe.draw.line({
				p0: new Vector(bounds.x, curH),
				p1: new Vector(bounds.x + bounds.w, curH),
				immediate: true,
				color: c,
				depth: 1000,
				//batcher: Luxe.renderer.batcher
				batcher: Main.instance.uiSceneBatcher
			});
		}
		*/

		var i = 0;

		for (h in layerLineHeights()) {

			var c = (i == Main.instance.curLayer) ? new Color(255,255,0) : new Color(255,255,255);

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
	}

	override function onmousedown(e : MouseEvent) {

		if ( Collision.pointInPoly(e.pos, polygon.getRectCollisionBounds()) ) {
			selectLayerWithCursor(e.pos.y);
			isActive = true;
		}
	}

	override function onmousemove(e : MouseEvent) {
		if ( isActive ) {
			selectLayerWithCursor(e.pos.y);
		}
	}

	override function onmouseup(e : MouseEvent) {
		isActive = false;
	}

	function selectLayerWithCursor(cursorHeight:Float) {
		//FIND CLOSEST LAYER
		var i = 0;
		var closestLayer = 0;
		var heights = layerLineHeights();
		for (h in heights) {
			var closestDist = Math.abs(cursorHeight - heights[closestLayer]);
			var testDist = Math.abs(cursorHeight - h);

			if (testDist < closestDist) {
				closestLayer = i;
			}

			i++;
		}

		//SELECT LAYER
		Main.instance.goToLayer(closestLayer);

		//CREATE THUMBNAIL
		if (thumbnailPoly != null) {

			//THIS NEEDS TO BE REFACTORED BRO
			Main.instance.uiSceneBatcher.remove(thumbnailPoly.geometry);
			for (c in thumbnailPoly.children) {
				Main.instance.uiSceneBatcher.remove( cast(c, Visual).geometry );
			}
		}

		var thumbWidth = 100;
		thumbnailPoly = new Polygon({batcher: Main.instance.uiSceneBatcher, depth: 2000}, [],
										Main.instance.curPoly().jsonRepresentation());

		thumbnailPoly.pos.y = heights[closestLayer];
		thumbnailPoly.pos.x = bounds.x + bounds.w + thumbWidth/2;

		var scaleRatio = thumbnailPoly.getRectBounds().w / thumbWidth;
		thumbnailPoly.scale = thumbnailPoly.scale.divideScalar(scaleRatio);
	}

	//from lowest to highest
	function layerLineHeights() : Array<Float> {
		var heights : Array<Float> = [];
		var numLayers = Main.instance.layers.getNumLayers();
		for (i in 0 ... numLayers) {
			var curH = bounds.y + (bounds.h * ( 1 - ((i+1) / (numLayers+1)) ) );
			heights.push(curH);
		}
		return heights;
	}

}
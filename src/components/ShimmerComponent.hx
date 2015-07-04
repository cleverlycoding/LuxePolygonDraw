package components;
import components.EditorComponent;

import luxe.Component;
import luxe.utils.Maths;
import luxe.Color;
import luxe.Timer;

import Polygon;

class ShimmerComponent extends EditorComponent {

	var polygon : Polygon;
	var originalColor : ColorHSV;
	var shimmerTimer : Timer = new Timer(Luxe.core);

	override function init() {
		polygon = cast entity;

		originalColor = polygon.color.toColorHSV();

		randomizeColors();

		shimmerTimer.schedule(1, randomizeColors, true);
	}

	override function update(dt : Float) {
		
	}

	override function onremoved() {
	}

	function randomizeColors() {
		var i = 0;
		while (i < polygon.geometry.vertices.length) {
			var v0 = polygon.geometry.vertices[i];
			var v1 = polygon.geometry.vertices[i+1];
			var v2 = polygon.geometry.vertices[i+2];

			//var colorTmp = originalColor. //v0.color.toColorHSV();
			var colorTmp = originalColor.clone();
			colorTmp.s = Maths.random_float(0.5, 1.0);

			v0.color = colorTmp;
			v1.color = colorTmp;
			v2.color = colorTmp;

			i += 3;
		}
	}
}
